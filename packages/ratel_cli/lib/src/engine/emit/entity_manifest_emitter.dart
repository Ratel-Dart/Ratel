import 'package:analyzer/dart/element/type.dart';

import '../../project/project_runtimes.dart';
import '../analysis/column_types.dart';
import '../analysis/element_queries.dart';
import '../model/column_kind.dart';
import '../model/constructor_argument.dart';
import '../model/scanned_column.dart';
import '../model/scanned_entity.dart';
import 'constant_emitter.dart';
import 'dart_literal.dart';
import 'import_allocator.dart';
import 'import_uris.dart';
import 'name_allocator.dart';
import 'type_emitter.dart';

final class EntityManifestEmitter {
  EntityManifestEmitter(ImportUris uris)
      : _imports = ImportAllocator(
          uris,
          runtimes: const ProjectRuntimes(framework: false, orm: true),
        ) {
    _types = TypeEmitter(_imports);
  }

  static const className = 'RatelEntityManifest';
  static const file = 'ratel_entity_manifest.dart';

  final ImportAllocator _imports;
  late final TypeEmitter _types;
  final NameAllocator _names = NameAllocator();
  final List<String> _members = [];

  static const _o = ImportAllocator.ormPrefix;

  String emit(List<ScannedEntity> entities) {
    final definitions = [for (final entity in entities) _definition(entity)];
    final body = StringBuffer()
      ..writeln('abstract final class $className {')
      ..writeln(
          '  static const $_o.EntityManifest manifest = $_o.EntityManifest(')
      ..writeln('    entities: [')
      ..writeAll(definitions)
      ..writeln('    ],')
      ..writeln('  );');
    for (final member in _members) {
      body
        ..writeln()
        ..write(member);
    }
    body.writeln('}');
    return '${_imports.directives().join('\n\n')}\n\n$body';
  }

  String _definition(ScannedEntity entity) {
    final type = _types.nonNullable(entity.element.thisType);
    final fromRow = _names.allocate([entity.name, 'FromRow']);
    final toRow = _names.allocate([entity.name, 'ToRow']);
    _members
      ..add(_fromRow(entity, type, fromRow))
      ..add(_toRow(entity, type, toRow));
    final buffer = StringBuffer()
      ..writeln('      $_o.EntityDefinition<$type>(')
      ..writeln('        name: ${DartLiteral.string(entity.name)},');
    final table = entity.table;
    if (table != null) {
      buffer.writeln('        table: ${DartLiteral.string(table)},');
    }
    buffer.writeln('        columns: [');
    for (final column in entity.columns) {
      final name = column.name;
      final parts = [
        'field: ${DartLiteral.string(column.field)}',
        if (name != null) 'name: ${DartLiteral.string(name)}',
        if (column.isId) 'isId: true',
      ];
      buffer.writeln('          $_o.ColumnDefinition(${parts.join(', ')}),');
    }
    buffer
      ..writeln('        ],')
      ..writeln('        fromRow: $fromRow,')
      ..writeln('        toRow: $toRow,')
      ..writeln('      ),');
    return buffer.toString();
  }

  String _fromRow(ScannedEntity entity, String type, String name) {
    final columns = {for (final column in entity.columns) column.field: column};
    final plan = entity.construction;
    final arguments = StringBuffer();
    for (final argument in plan.arguments) {
      final named = argument.isNamed ? '${argument.name}: ' : '';
      arguments.writeln('        $named${_argument(argument, columns)},');
    }
    final created =
        plan.arguments.isEmpty ? '$type()' : '$type(\n$arguments      )';
    final cascades = StringBuffer();
    for (final field in plan.assignments) {
      final column = columns[field.name];
      if (column == null) continue;
      cascades
          .write('\n        ..${field.name} = ${_read(field.type, column)}');
    }
    return '  static $type $name($_o.EntityRow row) =>\n'
        '      $created$cascades;\n';
  }

  String _argument(
    ConstructorArgument argument,
    Map<String, ScannedColumn> columns,
  ) {
    final column = columns[argument.property];
    if (column != null) return _read(argument.type, column);
    final value = argument.defaultValue;
    if (value == null) return 'null';
    return ConstantEmitter.emit(value, _types.emit) ?? 'null';
  }

  String _read(DartType target, ScannedColumn column) {
    var kind = ColumnTypes.kind(target);
    var type = target;
    if (kind == ColumnKind.unsupported) {
      kind = column.kind;
      type = column.type;
    }
    final nullable = target is DynamicType || ColumnTypes.isNullable(target);
    final method = nullable ? '${kind.name}OrNull' : kind.name;
    final field = DartLiteral.string(column.field);
    if (kind == ColumnKind.enumeration) {
      return 'row.$method($field, ${_types.nonNullable(type)}.values)';
    }
    return 'row.$method($field)';
  }

  String _toRow(ScannedEntity entity, String type, String name) {
    final entries = StringBuffer();
    for (final column in entity.columns) {
      final key = DartLiteral.string(column.field);
      entries.writeln('        $key: ${_write(column)},');
    }
    return '  static Map<String, Object?> $name($type entity) =>\n'
        '      <String, Object?>{\n'
        '$entries'
        '      };\n';
  }

  static String _write(ScannedColumn column) {
    final source = 'entity.${column.field}';
    if (column.kind != ColumnKind.enumeration) return source;
    String named(String value) => ElementQueries.declaresName(column.type)
        ? 'EnumName($value).name'
        : '$value.name';
    if (!ColumnTypes.isNullable(column.type)) return named(source);
    return 'switch ($source) { null => null, final value => ${named('value')} }';
  }
}
