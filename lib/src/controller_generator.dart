import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

const _url = 'package:ratel/annotations/annotations.dart';
const _handler =
    TypeChecker.fromUrl('package:ratel/http/handler.dart#RatelHandler');
const _controller = TypeChecker.fromUrl('$_url#Controller');
const _protected = TypeChecker.fromUrl('$_url#Protected');
const _public = TypeChecker.fromUrl('$_url#Public');
const _body = TypeChecker.fromUrl('$_url#Body');
const _param = TypeChecker.fromUrl('$_url#Param');
const _pathParam = TypeChecker.fromUrl('$_url#PathParam');
const _header = TypeChecker.fromUrl('$_url#Header');
const _cookie = TypeChecker.fromUrl('$_url#CookieParam');

final _verbs = <(TypeChecker, String)>[
  (TypeChecker.fromUrl('$_url#Get'), 'GET'),
  (TypeChecker.fromUrl('$_url#Post'), 'POST'),
  (TypeChecker.fromUrl('$_url#Put'), 'PUT'),
  (TypeChecker.fromUrl('$_url#Delete'), 'DELETE'),
  (TypeChecker.fromUrl('$_url#Patch'), 'PATCH'),
  (TypeChecker.fromUrl('$_url#Head'), 'HEAD'),
  (TypeChecker.fromUrl('$_url#Options'), 'OPTIONS'),
];

/// Emits `_$<Name>Routes` for every controller (a `RatelHandler` subclass),
/// replacing the reflective route scanning and parameter binding.
class ControllerGenerator extends Generator {
  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final output = StringBuffer();
    for (final element in library.classes) {
      if (element.name == 'RatelHandler') continue;
      if (!_handler.isAssignableFrom(element)) continue;
      output.writeln(_routes(element));
    }
    final result = output.toString().trim();
    return result.isEmpty ? null : result;
  }

  String _routes(ClassElement controller) {
    final name = controller.name;
    final prefix = _readString(_controller.firstAnnotationOf(controller), 'prefix') ?? '';
    final classProtected = _protected.firstAnnotationOf(controller);

    final registrations = <String>[];
    for (final method in controller.methods) {
      if (method.isStatic) continue;
      for (final (checker, verb) in _verbs) {
        final annotation = checker.firstAnnotationOf(method);
        if (annotation == null) continue;
        final path = _readString(annotation, 'path') ?? '';
        registrations.add(
          _registration(controller, method, verb, _joinPath(prefix, path),
              classProtected),
        );
      }
    }

    return 'void _\$${name}Routes($name controller) {\n'
        '${registrations.join('\n')}\n'
        '}';
  }

  String _registration(
    ClassElement controller,
    MethodElement method,
    String verb,
    String fullPath,
    DartObject? classProtected,
  ) {
    final methodProtected = _protected.firstAnnotationOf(method);
    final methodPublic = _public.hasAnnotationOf(method);
    final effective =
        methodProtected ?? (methodPublic ? null : classProtected);
    final isProtected = effective != null;
    final roles = _readRoles(effective).map((r) => "'$r'").join(', ');

    final hasBody = method.parameters.any((p) => _body.hasAnnotationOf(p));
    final args = method.parameters.map(_arg).join(', ');

    final buffer = StringBuffer()
      ..writeln('  RatelHandler.register(Route(')
      ..writeln("    path: '$fullPath',")
      ..writeln("    method: '$verb',")
      ..writeln('    isProtected: $isProtected,')
      ..writeln('    requiredRoles: const [$roles],')
      ..writeln('    handler: ([ctxArg]) async {')
      ..writeln('      final ctx = ctxArg as RequestContext;');
    if (hasBody) {
      buffer
        ..writeln('      final requestBody =')
        ..writeln('          await readBodyLimited('
            'ctx.request, RatelHandler.maxRequestBodyBytes);')
        ..writeln('      final jsonBody = requestBody.isNotEmpty')
        ..writeln('          ? decodeBody(ctx.request, requestBody)')
        ..writeln('          : const <String, dynamic>{};');
    }
    buffer
      ..writeln('      return await controller.${method.name}($args);')
      ..writeln('    },')
      ..write('  ));');
    return buffer.toString();
  }

  String _arg(ParameterElement param) {
    final full = param.type.getDisplayString(withNullability: true);
    final base = param.type.getDisplayString(withNullability: false);

    if (_body.hasAnnotationOf(param)) {
      return '$base.fromJson(jsonBody)';
    }
    final path = _pathParam.firstAnnotationOf(param);
    if (path != null) {
      final name = _readString(path, 'name');
      return "coerceParam('$name', ctx.pathParams['$name'], $base) as $full";
    }
    if (_param.hasAnnotationOf(param)) {
      final name = param.name;
      return "coerceParam('$name', "
          "ctx.request.uri.queryParameters['$name'], $base) as $full";
    }
    final header = _header.firstAnnotationOf(param);
    if (header != null) {
      final name = _readString(header, 'name');
      return "coerceParam('$name', ctx.request.headers.value('$name'), "
          "$base) as $full";
    }
    final cookie = _cookie.firstAnnotationOf(param);
    if (cookie != null) {
      final name = _readString(cookie, 'name');
      return "coerceParam('$name', "
          "cookieValue(ctx.request.cookies, '$name'), $base) as $full";
    }
    return 'null';
  }
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
