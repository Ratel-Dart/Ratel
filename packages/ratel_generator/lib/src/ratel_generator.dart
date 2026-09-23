import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

const _annotations = 'package:ratel/annotations/annotations.dart';

const _handlerChecker =
    TypeChecker.fromUrl('package:ratel/http/handler.dart#RatelHandler');
const _jsonChecker = TypeChecker.fromUrl('$_annotations#Json');
const _columnChecker =
    TypeChecker.fromUrl('package:ratel_orm/src/annotations.dart#Column');
const _controllerChecker = TypeChecker.fromUrl('$_annotations#Controller');
const _protectedChecker = TypeChecker.fromUrl('$_annotations#Protected');
const _publicChecker = TypeChecker.fromUrl('$_annotations#Public');
const _bodyChecker = TypeChecker.fromUrl('$_annotations#Body');
const _paramChecker = TypeChecker.fromUrl('$_annotations#Param');
const _pathParamChecker = TypeChecker.fromUrl('$_annotations#PathParam');
const _headerChecker = TypeChecker.fromUrl('$_annotations#Header');
const _cookieChecker = TypeChecker.fromUrl('$_annotations#CookieParam');

const _verbs = <(TypeChecker, String)>[
  (TypeChecker.fromUrl('$_annotations#Get'), 'GET'),
  (TypeChecker.fromUrl('$_annotations#Post'), 'POST'),
  (TypeChecker.fromUrl('$_annotations#Put'), 'PUT'),
  (TypeChecker.fromUrl('$_annotations#Delete'), 'DELETE'),
  (TypeChecker.fromUrl('$_annotations#Patch'), 'PATCH'),
  (TypeChecker.fromUrl('$_annotations#Head'), 'HEAD'),
  (TypeChecker.fromUrl('$_annotations#Options'), 'OPTIONS'),
];

/// Generates a standalone `<file>.ratel.dart` library for every source file
/// holding `@Json` classes, controllers or `@Column` entities.
///
/// The three concerns share one generator because they contribute to a single
/// `$registerRatel()` entry point and to one conditional import block: a file
/// with no `@Column` must not import `package:ratel_orm/ratel_orm.dart`.
class RatelGenerator extends Generator {
  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final jsonClasses = <ClassElement>[];
    final controllers = <ClassElement>[];
    final entities = <ClassElement, List<FieldElement>>{};

    for (final element in library.classes) {
      if (_jsonChecker.hasAnnotationOfExact(element)) {
        _requirePublic(element, 'A @Json class');
        jsonClasses.add(element);
      }
      if (element.name != 'RatelHandler' &&
          !element.isAbstract &&
          _handlerChecker.isAssignableFrom(element)) {
        _requirePublic(element, 'A controller');
        controllers.add(element);
      }
      final columns = element.fields
          .where((f) =>
              !f.isStatic &&
              !f.isSynthetic &&
              _columnChecker.hasAnnotationOf(f))
          .toList();
      if (columns.isNotEmpty) {
        _requirePublic(element, 'An @Column entity');
        entities[element] = columns;
      }
    }

    if (jsonClasses.isEmpty && controllers.isEmpty && entities.isEmpty) {
      return null;
    }

    final ctx = _Ctx(library, buildStep);
    final declarations = StringBuffer();
    final registrations = <String>[];

    for (final element in jsonClasses) {
      declarations
        ..writeln(_toJson(element))
        ..writeln();
      final fromJson = _fromJson(element);
      if (fromJson != null) {
        declarations
          ..writeln(fromJson)
          ..writeln();
      }
      registrations.add(
        '  _r.RatelJson.register<${element.name}>(\$${element.name}ToJson);',
      );
    }

    for (final element in entities.keys) {
      declarations
        ..writeln(_fromRow(element, entities[element]!))
        ..writeln();
      registrations.add(
        '  _orm.RatelRowMappers.register<${element.name}>'
        '(\$${element.name}FromRow);',
      );
    }

    for (final element in controllers) {
      declarations
        ..writeln(_routes(element, ctx))
        ..writeln();
      // The route table resolves its controller through RatelControllers so an
      // application can supply one built with its own dependencies. Only
      // controllers that can actually be constructed get a default.
      if (_canConstruct(element)) {
        registrations.add(
          '  _r.RatelControllers.registerDefault<${element.name}>'
          '(${element.name}.new);',
        );
      }
      registrations.add(
        '  \$${element.name}Routes'
        '(() => _r.RatelControllers.create<${element.name}>());',
      );
    }

    final source = buildStep.inputId.pathSegments.last;
    final header = StringBuffer();
    if (jsonClasses.isNotEmpty || controllers.isNotEmpty) {
      header.writeln("import 'package:ratel/ratel.dart' as _r;");
    }
    if (entities.isNotEmpty) {
      header.writeln("import 'package:ratel_orm/ratel_orm.dart' as _orm;");
    }
    header.writeln("import '$source';");
    for (final entry in ctx.imports.entries) {
      header.writeln("import '${entry.key}' as ${entry.value};");
    }

    return '$header\n'
        '$declarations'
        'void \$registerRatel() {\n'
        '${registrations.join('\n')}\n'
        '}';
  }

  String _toJson(ClassElement element) {
    final name = element.name;
    final entries = <String>[];
    for (final field in _serializableFields(element)) {
      entries.add("'${field.name}': instance.${field.name},");
    }
    for (final accessor in element.accessors) {
      if (!accessor.isGetter ||
          accessor.isStatic ||
          accessor.isPrivate ||
          accessor.isSynthetic) {
        continue;
      }
      entries.add("'${accessor.name}': instance.${accessor.name},");
    }
    final body = entries.map((e) => '      $e').join('\n');
    return 'Map<String, dynamic> \$${name}ToJson($name instance) =>\n'
        '    <String, dynamic>{\n$body\n    };';
  }

  String? _fromJson(ClassElement element) {
    if (!_canConstruct(element)) return null;
    final name = element.name;
    final lines = <String>['final instance = $name();'];
    for (final field in _serializableFields(element)) {
      if (field.isFinal) continue;
      final type = field.type.getDisplayString(withNullability: true);
      lines.add(
        "if (json.containsKey('${field.name}')) "
        "instance.${field.name} = json['${field.name}'] as $type;",
      );
    }
    lines.add('return instance;');
    final body = lines.map((l) => '  $l').join('\n');
    return '$name \$${name}FromJson(Map<String, dynamic> json) {\n$body\n}';
  }

  String _fromRow(ClassElement element, List<FieldElement> columns) {
    final name = element.name;
    final lines = <String>['final entity = $name();'];
    for (final field in columns) {
      final annotation = _columnChecker.firstAnnotationOf(field);
      final column =
          (_readString(annotation, 'name') ?? field.name).toLowerCase();
      final type = field.type.getDisplayString(withNullability: true);
      lines.add(
        "if (row.containsKey('$column')) "
        "entity.${field.name} = row['$column'] as $type;",
      );
    }
    lines.add('return entity;');
    final body = lines.map((l) => '  $l').join('\n');
    return '$name \$${name}FromRow(Map<String, Object?> row) {\n$body\n}';
  }

  String _routes(ClassElement controller, _Ctx ctx) {
    final name = controller.name;
    final prefix = _readString(
            _controllerChecker.firstAnnotationOf(controller), 'prefix') ??
        '';
    final classProtected = _protectedChecker.firstAnnotationOf(controller);

    final registrations = <String>[];
    for (final method in controller.methods) {
      if (method.isStatic) continue;
      for (final (checker, verb) in _verbs) {
        final annotation = checker.firstAnnotationOf(method);
        if (annotation == null) continue;
        final path = _readString(annotation, 'path') ?? '';
        registrations.add(_registration(
          method,
          verb,
          _joinPath(prefix, path),
          classProtected,
          ctx,
        ));
      }
    }

    return 'void \$${name}Routes($name Function() factory) {\n'
        '  $name? instance;\n'
        '  $name controller() => instance ??= factory();\n'
        '${registrations.join('\n')}\n'
        '}';
  }

  String _registration(
    MethodElement method,
    String verb,
    String fullPath,
    DartObject? classProtected,
    _Ctx ctx,
  ) {
    final methodProtected = _protectedChecker.firstAnnotationOf(method);
    final methodPublic = _publicChecker.hasAnnotationOf(method);
    final effective = methodProtected ?? (methodPublic ? null : classProtected);
    final isProtected = effective != null;
    final roles = _readRoles(effective).map((r) => "'$r'").join(', ');

    final hasBody =
        method.parameters.any((p) => _bodyChecker.hasAnnotationOf(p));
    final args = method.parameters.map((param) => _arg(param, ctx)).join(', ');

    final buffer = StringBuffer()
      ..writeln('  _r.RatelHandler.register(_r.Route(')
      ..writeln("    path: '$fullPath',")
      ..writeln("    method: '$verb',")
      ..writeln('    isProtected: $isProtected,')
      ..writeln('    requiredRoles: const [$roles],')
      ..writeln('    handler: ([ctxArg]) async {')
      ..writeln('      final ctx = ctxArg as _r.RequestContext;');
    if (hasBody) {
      buffer
        ..writeln('      final requestBody = await _r.readBodyLimited(')
        ..writeln(
            '          ctx.request, _r.RatelHandler.maxRequestBodyBytes);')
        ..writeln('      final jsonBody = requestBody.isNotEmpty')
        ..writeln('          ? _r.decodeBody(ctx.request, requestBody)')
        ..writeln('          : const <String, dynamic>{};');
    }
    buffer
      ..writeln('      return await controller().${method.name}($args);')
      ..writeln('    },')
      ..write('  ));');
    return buffer.toString();
  }

  String _arg(ParameterElement param, _Ctx ctx) {
    final full = param.type.getDisplayString(withNullability: true);
    final base = param.type.getDisplayString(withNullability: false);

    if (_bodyChecker.hasAnnotationOf(param)) {
      return '${_fromJsonRef(param.type, ctx)}(jsonBody)';
    }
    final path = _pathParamChecker.firstAnnotationOf(param);
    if (path != null) {
      final name = _readString(path, 'name');
      return "_r.coerceParam('$name', ctx.pathParams['$name'], $base) as $full";
    }
    if (_paramChecker.hasAnnotationOf(param)) {
      final name = param.name;
      return "_r.coerceParam('$name', "
          "ctx.request.uri.queryParameters['$name'], $base) as $full";
    }
    final header = _headerChecker.firstAnnotationOf(param);
    if (header != null) {
      final name = _readString(header, 'name');
      return "_r.coerceParam('$name', ctx.request.headers.value('$name'), "
          "$base) as $full";
    }
    final cookie = _cookieChecker.firstAnnotationOf(param);
    if (cookie != null) {
      final name = _readString(cookie, 'name');
      return "_r.coerceParam('$name', "
          "_r.cookieValue(ctx.request.cookies, '$name'), $base) as $full";
    }
    return 'null';
  }

  String _fromJsonRef(DartType type, _Ctx ctx) {
    final element = type.element;
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'A @Body() parameter must be a class annotated with @Json(); '
        'got ${type.getDisplayString(withNullability: false)}.',
      );
    }
    if (!_jsonChecker.hasAnnotationOfExact(element)) {
      throw InvalidGenerationSourceError(
        'The @Body() type ${element.name} is not annotated with @Json(), so no '
        'deserializer is generated for it. Add @Json() to ${element.name}.',
        element: element,
      );
    }
    if (!_canConstruct(element)) {
      throw InvalidGenerationSourceError(
        'The @Body() type ${element.name} has no zero-argument constructor, so '
        'it cannot be deserialized. Give ${element.name} a constructor whose '
        'parameters are all optional.',
        element: element,
      );
    }
    final name = '\$${element.name}FromJson';
    if (element.library == ctx.library.element) return name;
    return '${ctx.imports.prefixFor(_generatedUri(element, ctx.buildStep))}'
        '.$name';
  }

  /// The import URI of the library generated for [element]'s own library.
  ///
  /// Libraries under `lib/` resolve as `package:` URIs and are imported as
  /// such. Everything else (`test/`, `bin/`, `example/`) resolves as an `asset:`
  /// URI, which is not importable, so it becomes a path relative to the file
  /// being generated for.
  String _generatedUri(ClassElement element, BuildStep buildStep) {
    final uri = element.library.source.uri;
    if (uri.isScheme('package')) return _swapExtension(uri.toString());
    if (uri.isScheme('asset')) {
      final id = AssetId.resolve(uri);
      final from = p.url.dirname(buildStep.inputId.path);
      return _swapExtension(p.url.relative(id.path, from: from));
    }
    throw InvalidGenerationSourceError(
      'Cannot import generated code for ${element.name}, declared in $uri.',
      element: element,
    );
  }
}

void _requirePublic(ClassElement element, String what) {
  if (!element.isPrivate) return;
  throw InvalidGenerationSourceError(
    '$what must be public. Generated code lives in a separate library and '
    'cannot reference ${element.name}. Rename it without the leading '
    'underscore.',
    element: element,
  );
}

String _swapExtension(String uri) =>
    '${uri.substring(0, uri.length - '.dart'.length)}.ratel.dart';

Iterable<FieldElement> _serializableFields(ClassElement element) =>
    element.fields.where(
      (f) => !f.isStatic && !f.isPrivate && !f.isSynthetic,
    );

bool _canConstruct(ClassElement element) => element.constructors.any(
      (c) => c.name.isEmpty && c.parameters.every((p) => p.isOptional),
    );

/// Per-file generation state: the library being read, the build step it came
/// from (needed to resolve sibling assets) and the imports collected so far.
class _Ctx {
  _Ctx(this.library, this.buildStep);

  final LibraryReader library;
  final BuildStep buildStep;
  final _Imports imports = _Imports();
}

class _Imports {
  final Map<String, String> _prefixes = {};

  Iterable<MapEntry<String, String>> get entries => _prefixes.entries;

  String prefixFor(String uri) =>
      _prefixes.putIfAbsent(uri, () => '_m${_prefixes.length}');
}

String? _readString(DartObject? object, String field) {
  if (object == null) return null;
  final reader = ConstantReader(object).read(field);
  return reader.isString ? reader.stringValue : null;
}

List<String> _readRoles(DartObject? object) {
  if (object == null) return const [];
  final reader = ConstantReader(object).read('roles');
  if (reader.isNull) return const [];
  return reader.listValue.map((e) => e.toStringValue() ?? '').toList();
}

String _joinPath(String prefix, String path) {
  if (prefix.isEmpty) return path;
  var base =
      prefix.endsWith('/') ? prefix.substring(0, prefix.length - 1) : prefix;
  if (!base.startsWith('/')) base = '/$base';
  final tail = path.startsWith('/') ? path : '/$path';
  var joined = '$base$tail';
  if (joined.length > 1 && joined.endsWith('/')) {
    joined = joined.substring(0, joined.length - 1);
  }
  return joined;
}
