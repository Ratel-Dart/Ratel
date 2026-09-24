import 'package:analyzer/dart/element/element.dart';

import '../diagnostics/diagnostic_codes.dart';
import '../diagnostics/diagnostic_severity.dart';
import '../diagnostics/element_diagnostics.dart';
import '../diagnostics/ratel_diagnostic.dart';
import '../emit/constant_emitter.dart';
import '../model/column_kind.dart';
import '../model/construction_plan.dart';
import '../model/scanned_column.dart';
import '../model/scanned_entity.dart';
import '../model/scanned_field.dart';
import 'column_types.dart';
import 'constant_values.dart';
import 'construction_planner.dart';
import 'element_queries.dart';
import 'json_types.dart';
import 'orm_annotations.dart';
import 'sql_names.dart';

final class EntityScanner {
  EntityScanner._(this._diagnostics);

  final List<RatelDiagnostic> _diagnostics;
  final Set<String> _reported = {};

  static List<ScannedEntity> scan(
    List<LibraryElement> libraries,
    List<RatelDiagnostic> diagnostics,
  ) {
    final scanner = EntityScanner._(diagnostics);
    final annotated = annotatedIn(libraries);
    final entities = <ScannedEntity>[];
    for (final element in annotated) {
      final entity = scanner._entity(element);
      if (entity != null) entities.add(entity);
    }
    scanner._tables(entities);
    final mapped = {
      for (final element in annotated)
        for (final level in ElementQueries.lineage(element.thisType))
          level.element,
    };
    for (final library in libraries) {
      scanner._walk(library, mapped);
    }
    return entities;
  }

  static List<ClassElement> annotatedIn(List<LibraryElement> libraries) => [
        for (final library in libraries)
          for (final element in library.classes)
            if (OrmAnnotations.has(element, OrmAnnotations.entity)) element,
      ];

  ScannedEntity? _entity(ClassElement element) {
    final name = element.name ?? '';
    if (element.isPrivate) {
      _report(
        element,
        DiagnosticCodes.privateClass,
        'The entity $name must be public: the generated entity mapper lives '
        'in another library. Rename it without the leading underscore.',
      );
      return null;
    }
    if (element.isAbstract || element.isSealed) {
      _report(
        element,
        DiagnosticCodes.entityAbstract,
        'The entity $name is abstract, so Ratel cannot create it from a row. '
        'Put @Entity on a concrete class.',
      );
      return null;
    }
    if (element.typeParameters.isNotEmpty) {
      _report(
        element,
        DiagnosticCodes.entityGeneric,
        'The entity $name is generic, so Ratel cannot tell which types its '
        'columns hold. Put @Entity on a class without type parameters.',
      );
      return null;
    }
    final (columns, valid) = _columns(element);
    final ids = columns.where((column) => column.isId).toList();
    if (ids.isEmpty && !_marksUnusableId(element)) {
      _report(
        element,
        DiagnosticCodes.entityNoId,
        'The entity $name has no @Id() field. Mark the public field that '
        'holds its primary key with @Id().',
      );
    } else if (ids.length > 1) {
      _report(
        element,
        DiagnosticCodes.entityMultipleIds,
        'The entity $name marks ${ids.map((id) => id.field).join(', ')} with '
        '@Id(), but an entity has exactly one id. Keep @Id() on one of them.',
      );
    }
    if (!valid) return null;
    final table = ConstantValues.string(
      OrmAnnotations.first(element, OrmAnnotations.entity),
      'table',
    );
    final named = _names(element, table, columns);
    final construction = _construction(element, columns);
    if (!named || construction == null || ids.length != 1) return null;
    return ScannedEntity(
      element: element,
      columns: columns,
      construction: construction,
      table: table,
    );
  }

  bool _names(
    ClassElement element,
    String? table,
    List<ScannedColumn> columns,
  ) {
    final name = element.name ?? '';
    var valid = true;
    if (table != null && table.isEmpty) {
      valid = false;
      _report(
        element,
        DiagnosticCodes.entityEmptyName,
        "The entity $name sets an empty table name with @Entity(table: ''). "
        'Name the table, or remove table: to use "${SqlNames.of(name)}".',
      );
    }
    final owners = <String, ScannedColumn>{};
    for (final column in columns) {
      final label = '$name.${column.field}';
      final explicit = column.name;
      if (explicit != null && explicit.isEmpty) {
        valid = false;
        _report(
          column.element,
          DiagnosticCodes.entityEmptyName,
          "$label sets an empty column name with @Column(name: ''). Name the "
          'column, or remove name: to use "${SqlNames.of(column.field)}".',
        );
        continue;
      }
      final effective = explicit ?? SqlNames.of(column.field);
      final owner = owners[effective];
      if (owner == null) {
        owners[effective] = column;
        continue;
      }
      valid = false;
      _report(
        column.element,
        DiagnosticCodes.entityColumnClash,
        '$label maps to the column "$effective", which $name.${owner.field} '
        'already uses. Give one of them another column name with '
        "@Column(name: '...').",
      );
    }
    return valid;
  }

  void _tables(List<ScannedEntity> entities) {
    final owners = <String, ScannedEntity>{};
    for (final entity in entities) {
      final table = entity.table ?? SqlNames.of(entity.name);
      final owner = owners[table];
      if (owner == null) {
        owners[table] = entity;
        continue;
      }
      _report(
        entity.element,
        DiagnosticCodes.entityTableClash,
        'The entities ${_qualified(owner.element)} and '
        '${_qualified(entity.element)} both map to the table "$table", so '
        'they read and write the same rows. If that is not intended, give one '
        "of them its own table with @Entity(table: '...').",
        severity: DiagnosticSeverity.warning,
      );
    }
  }

  static String _qualified(ClassElement element) =>
      '${element.name} (${element.library.uri})';

  (List<ScannedColumn>, bool) _columns(ClassElement element) {
    final name = element.name ?? '';
    final byName = <String, ScannedColumn>{};
    var valid = true;
    for (final level in ElementQueries.lineage(element.thisType)) {
      for (final field in level.element.fields) {
        if (field.isStatic || field.isAbstract || field.isExternal) continue;
        if (!field.isOriginDeclaration &&
            !field.isOriginDeclaringFormalParameter) {
          continue;
        }
        final fieldName = field.name ?? '';
        final label = '$name.$fieldName';
        final isId = OrmAnnotations.has(field, OrmAnnotations.id);
        byName.remove(fieldName);
        if (OrmAnnotations.has(field, OrmAnnotations.transient)) {
          if (isId) {
            valid = false;
            _report(
              field,
              DiagnosticCodes.ormAnnotationMisplaced,
              '$label is marked both @Id() and @Transient(), but a '
              '@Transient() field is not a column and cannot be the id. '
              'Remove one of them.',
            );
          }
          continue;
        }
        if (field.isPrivate) {
          final marks = OrmAnnotations.present(
            field,
            const [OrmAnnotations.id, OrmAnnotations.column],
          );
          if (marks.isNotEmpty) {
            valid = false;
            final listed = marks.map((mark) => '@$mark()').join(' and ');
            _report(
              field,
              DiagnosticCodes.entityPrivateField,
              '$label is marked $listed, but it is private, so it cannot be '
              'a column: the generated entity mapper lives in another '
              'library. Make it public, or remove $listed.',
            );
            continue;
          }
          _report(
            field,
            DiagnosticCodes.entityPrivateField,
            '$label is private, so it is not persisted: the generated entity '
            'mapper lives in another library. Make it public to store it, or '
            'mark it @Transient() to keep it out of the table.',
            severity: DiagnosticSeverity.warning,
          );
          continue;
        }
        final type = level.getGetter(fieldName)?.returnType ?? field.type;
        final kind = ColumnTypes.kind(type);
        final display = type.getDisplayString();
        if (ColumnTypes.isUnresolved(type)) {
          valid = false;
        } else if (kind == ColumnKind.unsupported) {
          valid = false;
          _report(
            field,
            DiagnosticCodes.entityUnsupportedType,
            '$label has type $display, which Ratel cannot store in a column. '
            'Use ${ColumnTypes.supported}, or mark the field @Transient() to '
            'keep it out of the table.',
          );
        } else if (!JsonTypes.isPublic(type)) {
          valid = false;
          _report(
            field,
            DiagnosticCodes.privateClass,
            '$label uses the private type $display. Ratel generates the '
            'entity mapper in another library, so the type must be public: '
            'rename it without the leading underscore.',
          );
        }
        byName[fieldName] = ScannedColumn(
          field: fieldName,
          type: type,
          kind: kind,
          element: field,
          name: ConstantValues.string(
            OrmAnnotations.first(field, OrmAnnotations.column),
            'name',
          ),
          isId: isId,
        );
      }
    }
    return (byName.values.toList(), valid);
  }

  static bool _marksUnusableId(ClassElement element) =>
      ElementQueries.lineage(element.thisType).any(
        (level) => level.element.fields.any(
          (field) =>
              !field.isStatic &&
              OrmAnnotations.has(field, OrmAnnotations.id) &&
              (field.isPrivate ||
                  OrmAnnotations.has(field, OrmAnnotations.transient)),
        ),
      );

  ConstructionPlan? _construction(
    ClassElement element,
    List<ScannedColumn> columns,
  ) {
    final name = element.name ?? '';
    final (:plan, :problem) = ConstructionPlanner.plan(
      element.thisType,
      properties: [
        for (final column in columns)
          ScannedField(
            name: column.field,
            type: column.type,
            element: column.element,
          ),
      ],
      matched: 'column',
    );
    if (plan == null) {
      _report(
        element,
        DiagnosticCodes.entityNotConstructible,
        'Ratel cannot create the entity $name from a row: $problem. Give '
        '$name a public unnamed constructor whose parameters are its columns.',
      );
      return null;
    }
    var valid = true;
    for (final argument in plan.arguments) {
      final value = argument.defaultValue;
      if (argument.property != null || value == null) continue;
      if (ConstantEmitter.canEmit(value)) continue;
      valid = false;
      _report(
        argument.element,
        DiagnosticCodes.entityNotConstructible,
        'Ratel cannot create the entity $name from a row: the default value '
        'of ${argument.name} cannot be copied into generated code. Give it a '
        'simpler default or make it a named parameter.',
      );
    }
    final settable = {
      for (final argument in plan.arguments) argument.property,
      for (final field in plan.assignments) field.name,
    };
    for (final column in columns) {
      if (settable.contains(column.field)) continue;
      valid = false;
      _report(
        column.element,
        DiagnosticCodes.entityUnsettableField,
        '$name.${column.field} is final and not a constructor parameter, so '
        'Ratel cannot set it from a row. Add it to the constructor of $name, '
        'or mark it @Transient() if it is not a column.',
      );
    }
    return valid ? plan : null;
  }

  void _walk(Element element, Set<InterfaceElement> mapped) {
    _check(element, mapped);
    for (final child in element.children) {
      _walk(child, mapped);
    }
  }

  void _check(Element element, Set<InterfaceElement> mapped) {
    if (element is FieldFormalParameterElement && element.isDeclaring) return;
    if (element is! ClassElement &&
        OrmAnnotations.has(element, OrmAnnotations.entity)) {
      _report(
        element,
        DiagnosticCodes.ormAnnotationMisplaced,
        '@Entity() on ${_describe(element)} has no effect: only classes are '
        'entities.',
      );
    }
    final found = [
      for (final name
          in OrmAnnotations.present(element, OrmAnnotations.fieldAnnotations))
        if (name != OrmAnnotations.transient || !_isMember(element, mapped))
          name,
    ];
    if (found.isEmpty) return;
    final problem = _placement(element, mapped);
    if (problem == null) return;
    _report(
      element,
      DiagnosticCodes.ormAnnotationMisplaced,
      '${found.map((name) => '@$name()').join(' and ')} on '
      '${_describe(element)} has no effect: $problem.',
    );
  }

  static bool _isMember(Element element, Set<InterfaceElement> mapped) =>
      element is! FormalParameterElement &&
      mapped.contains(element.enclosingElement);

  static String? _placement(Element element, Set<InterfaceElement> mapped) {
    if (element is FieldElement) {
      if (element.isStatic) return 'static fields are never columns';
      final owner = element.enclosingElement;
      if (mapped.contains(owner)) return null;
      return _unmapped(owner);
    }
    if (element is GetterElement || element is SetterElement) {
      return 'only fields are columns, getters and setters never are';
    }
    if (element is FieldFormalParameterElement) {
      return 'annotate the field ${element.field?.name ?? element.name} '
          'instead of the constructor parameter';
    }
    return 'only the fields of an @Entity class are columns';
  }

  static String _unmapped(InstanceElement owner) {
    final name = owner.name;
    if (owner is MixinElement) {
      return 'no @Entity class mixes in $name. Mix it into an @Entity class, '
          'or remove the annotation';
    }
    if (owner is ClassElement && (owner.isAbstract || owner.isSealed)) {
      return '$name is abstract and no @Entity class extends it. Extend it '
          'with a concrete @Entity class, or remove the annotation';
    }
    if (owner is ClassElement) {
      return '$name is not an @Entity. Annotate the class with @Entity() or '
          'remove the annotation';
    }
    return 'only the fields of an @Entity class are columns';
  }

  static String _describe(Element element) {
    final name = element.displayName;
    if (element is FormalParameterElement) {
      return element.enclosingElement is ConstructorElement
          ? 'the constructor parameter $name'
          : 'the parameter $name';
    }
    final enclosing = element.enclosingElement;
    if (enclosing is InstanceElement) return '${enclosing.name}.$name';
    return name;
  }

  void _report(
    Element element,
    String code,
    String message, {
    DiagnosticSeverity severity = DiagnosticSeverity.error,
  }) {
    final diagnostic = ElementDiagnostics.at(
      _located(element),
      code,
      message,
      severity: severity,
    );
    final identity =
        '$code ${diagnostic.path}:${diagnostic.line}:${diagnostic.column}';
    if (_reported.add(identity)) _diagnostics.add(diagnostic);
  }

  static Element _located(Element element) {
    final base = element.baseElement;
    if (base is FieldElement) return base.declaringFormalParameter ?? base;
    return base;
  }
}
