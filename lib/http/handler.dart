import 'dart:convert';
import 'dart:mirrors';

import '../annotations/annotations.dart';
import '../core/request_context.dart';
import '../exceptions/exceptions.dart';

/// Base class for controllers. Subclasses annotate methods with `@Get`, `@Post`,
/// etc.; constructing one scans those annotations (via reflection) and registers
/// the routes. A class-level `@Controller('/prefix')` prefixes every route.
abstract class RatelHandler {
  static final List<Route> routesList = [];

  /// Maximum accepted request body size, in bytes. Bodies larger than this are
  /// rejected with `413 Payload Too Large`. Configured via
  /// `RatelServer(maxRequestBodyBytes: ...)`; defaults to 1 MiB.
  static int maxRequestBodyBytes = 1024 * 1024;

  RatelHandler() {
    _registerRoutes();
  }

  void _registerRoutes() {
    final instance = reflect(this);
    final classMirror = instance.type;

    final prefix = _firstMeta<Controller>(classMirror.metadata)?.prefix ?? '';
    final classProtected = _firstMeta<Protected>(classMirror.metadata);

    for (final declaration in classMirror.declarations.values) {
      if (declaration is MethodMirror && declaration.isRegularMethod) {
        final methodProtected = _firstMeta<Protected>(declaration.metadata);
        final methodPublic =
            declaration.metadata.any((m) => m.reflectee is Public);
        final effective =
            methodProtected ?? (methodPublic ? null : classProtected);
        final isProtected = effective != null;
        final roles = effective?.roles ?? const <String>[];

        for (final metadata in declaration.metadata) {
          final httpMethod = _methodOf(metadata.reflectee);
          final routePath = _pathOf(metadata.reflectee);
          if (httpMethod != null && routePath != null) {
            final fullPath = _joinPath(prefix, routePath);
            _ensureUnique(fullPath, httpMethod);
            routes.add(_routerAdd(fullPath, httpMethod, instance, declaration,
                isProtected, roles));
          }
        }
      }
    }
  }

  void _ensureUnique(String path, String method) {
    final clash = routes.any((r) => r.path == path && r.method == method);
    if (clash) {
      throw StateError('Duplicate route registered: $method $path');
    }
  }

  Route _routerAdd(String path, String methodType, InstanceMirror instance,
      MethodMirror method, bool isProtected, List<String> roles) {
    final verb = methodType.toUpperCase();
    final hasBody =
        verb == 'POST' || verb == 'PUT' || verb == 'DELETE' || verb == 'PATCH';
    return Route(
      path: path,
      method: methodType,
      isProtected: isProtected,
      requiredRoles: roles,
      methodMirror: method,
      handler: ([dynamic ctxArg]) async {
        final ctx = ctxArg as RequestContext;
        final args = <dynamic>[];
        if (hasBody) {
          final body = await readBodyLimited(ctx.request, maxRequestBodyBytes);
          final jsonMap = body.isNotEmpty
              ? decodeJsonObject(body)
              : const <String, dynamic>{};
          for (final param in method.parameters) {
            if (param.metadata.any((m) => m.reflectee is Body)) {
              args.add(_deserializeBody(param, jsonMap));
            } else {
              args.add(_resolveParam(param, ctx));
            }
          }
        } else {
          for (final param in method.parameters) {
            args.add(_resolveParam(param, ctx));
          }
        }
        return await instance.invoke(method.simpleName, args).reflectee;
      },
    );
  }

  static List<Route> get routes => routesList;
}

T? _firstMeta<T>(Iterable<InstanceMirror> metadata) {
  for (final m in metadata) {
    final reflectee = m.reflectee;
    if (reflectee is T) return reflectee;
  }
  return null;
}

String? _methodOf(dynamic annotation) {
  if (annotation is Get) return 'GET';
  if (annotation is Post) return 'POST';
  if (annotation is Put) return 'PUT';
  if (annotation is Delete) return 'DELETE';
  if (annotation is Patch) return 'PATCH';
  if (annotation is Head) return 'HEAD';
  if (annotation is Options) return 'OPTIONS';
  return null;
}

String? _pathOf(dynamic annotation) {
  if (annotation is Get) return annotation.path;
  if (annotation is Post) return annotation.path;
  if (annotation is Put) return annotation.path;
  if (annotation is Delete) return annotation.path;
  if (annotation is Patch) return annotation.path;
  if (annotation is Head) return annotation.path;
  if (annotation is Options) return annotation.path;
  return null;
}

/// Joins a controller [prefix] with a route [path], collapsing slashes.
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

/// Resolves a `@PathParam` or `@Param` handler argument from [ctx], coercing the
/// string value to the parameter's declared type. Returns null when absent.
dynamic _resolveParam(ParameterMirror param, RequestContext ctx) {
  final type = param.type.reflectedType;
  for (final meta in param.metadata) {
    final reflectee = meta.reflectee;
    if (reflectee is PathParam) {
      final value = ctx.pathParams[reflectee.name];
      return value == null ? null : coerceParam(reflectee.name, value, type);
    }
    if (reflectee is Param) {
      final name = MirrorSystem.getName(param.simpleName);
      final value = ctx.request.uri.queryParameters[name];
      return value == null ? null : coerceParam(name, value, type);
    }
  }
  return null;
}

dynamic _deserializeBody(ParameterMirror param, Map<String, dynamic> jsonMap) {
  final typeMirror = reflectClass(param.type.reflectedType);
  final hasJson = typeMirror.metadata.any((m) => m.reflectee is Json);
  if (!hasJson) return null;
  return _generateFromJson(typeMirror, jsonMap);
}

dynamic _generateFromJson(
    ClassMirror typeMirror, Map<String, dynamic> jsonMap) {
  final instance = typeMirror.newInstance(Symbol(''), []);
  for (final field in typeMirror.declarations.values) {
    if (field is VariableMirror && !field.isStatic) {
      final fieldName = MirrorSystem.getName(field.simpleName);
      if (jsonMap.containsKey(fieldName)) {
        instance.setField(field.simpleName, jsonMap[fieldName]);
      }
    }
  }
  return instance.reflectee;
}

/// Parses a query/path [value] into [targetType] (`int`, `double`, `bool` or
/// `String`), throwing [BadRequestException] when the value is not valid for the
/// requested type. Invalid client input becomes a 400, never a 500.
dynamic coerceParam(String name, String value, Type targetType) {
  if (targetType == int) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw BadRequestException('Parameter "$name" must be an integer');
    }
    return parsed;
  }
  if (targetType == double) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw BadRequestException('Parameter "$name" must be a number');
    }
    return parsed;
  }
  if (targetType == bool) {
    return value.toLowerCase() == 'true';
  }
  return value;
}

/// Reads the full request body from [stream] as a UTF-8 string, rejecting
/// bodies larger than [maxBytes] with a [PayloadTooLargeException]. Counting
/// bytes as they arrive bounds memory even for chunked requests whose length is
/// unknown in advance.
Future<String> readBodyLimited(Stream<List<int>> stream, int maxBytes) async {
  final bytes = <int>[];
  var total = 0;
  await for (final chunk in stream) {
    total += chunk.length;
    if (total > maxBytes) {
      throw PayloadTooLargeException(
        'Request body exceeds the limit of $maxBytes bytes',
      );
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

/// Decodes [body] as a JSON object, throwing [BadRequestException] (400) for
/// invalid JSON or for a non-object top-level value (e.g. an array). This keeps
/// malformed client input from surfacing as a 500.
Map<String, dynamic> decodeJsonObject(String body) {
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw BadRequestException('Request body is not valid JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw BadRequestException('Request body must be a JSON object');
  }
  return decoded;
}
