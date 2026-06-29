import 'dart:convert';
import 'dart:mirrors';

import '../annotations/annotations.dart';
import '../exceptions/exceptions.dart';

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
    InstanceMirror instance = reflect(this);
    ClassMirror classMirror = instance.type;

    bool classProtected =
        classMirror.metadata.any((m) => m.reflectee is Protected);

    for (var declaration in classMirror.declarations.values) {
      if (declaration is MethodMirror && declaration.isRegularMethod) {
        bool methodPublic =
            declaration.metadata.any((m) => m.reflectee is Public);
        bool methodProtected =
            declaration.metadata.any((m) => m.reflectee is Protected);
        bool isProtected = (classProtected && !methodPublic) || methodProtected;
        for (var metadata in declaration.metadata) {
          String? httpMethod;
          String? path;
          var reflectee = metadata.reflectee;
          if (reflectee is Get) {
            httpMethod = "GET";
            path = reflectee.path;
          } else if (reflectee is Post) {
            httpMethod = "POST";
            path = reflectee.path;
          } else if (reflectee is Put) {
            httpMethod = "PUT";
            path = reflectee.path;
          } else if (reflectee is Delete) {
            httpMethod = "DELETE";
            path = reflectee.path;
          }

          if (httpMethod != null && path != null) {
            routes.add(_routerAdd(
                path, httpMethod, instance, declaration, isProtected));
          }
        }
      }
    }
  }

  Route _routerAdd(String path, String methodType, InstanceMirror instance,
      MethodMirror method, bool isProtected) {
    return Route(
      path: path,
      method: methodType,
      isProtected: isProtected,
      methodMirror: method,
      handler: ([dynamic request]) async {
        List<dynamic> args = [];
        String mType = methodType.toUpperCase();
        if (mType == "GET") {
          for (var param in method.parameters) {
            if (param.metadata.any((meta) => meta.reflectee is Param)) {
              String paramName = MirrorSystem.getName(param.simpleName);
              if (request.uri.queryParameters.containsKey(paramName)) {
                String valueStr = request.uri.queryParameters[paramName]!;
                Type paramType = param.type.reflectedType;
                args.add(coerceParam(paramName, valueStr, paramType));
              } else {
                args.add(null);
              }
            } else {
              args.add(null);
            }
          }
        } else if (mType == "POST" || mType == "PUT" || mType == "DELETE") {
          String bodyString =
              await readBodyLimited(request, maxRequestBodyBytes);
          if (bodyString.isNotEmpty) {
            final Map<String, dynamic> jsonMap = decodeJsonObject(bodyString);
            for (var param in method.parameters) {
              bool isBody =
                  param.metadata.any((meta) => meta.reflectee is Body);
              if (isBody) {
                Type paramType = param.type.reflectedType;
                ClassMirror typeMirror = reflectClass(paramType);
                bool hasJsonAnnotation =
                    typeMirror.metadata.any((m) => m.reflectee is Json);
                if (hasJsonAnnotation) {
                  var obj = _generateFromJson(typeMirror, jsonMap);
                  args.add(obj);
                } else {
                  args.add(null);
                }
              } else if (param.metadata
                  .any((meta) => meta.reflectee is Param)) {
                String paramName = MirrorSystem.getName(param.simpleName);
                if (request.uri.queryParameters.containsKey(paramName)) {
                  String valueStr = request.uri.queryParameters[paramName]!;
                  Type paramType = param.type.reflectedType;
                  args.add(coerceParam(paramName, valueStr, paramType));
                } else {
                  args.add(null);
                }
              } else {
                args.add(null);
              }
            }
          } else {
            args.addAll(List.filled(method.parameters.length, null));
          }
        } else {
          args = [];
        }
        return await instance.invoke(method.simpleName, args).reflectee;
      },
    );
  }

  dynamic _generateFromJson(
      ClassMirror typeMirror, Map<String, dynamic> jsonMap) {
    var instance = typeMirror.newInstance(Symbol(''), []);
    for (var field in typeMirror.declarations.values) {
      if (field is VariableMirror && !field.isStatic) {
        String fieldName = MirrorSystem.getName(field.simpleName);
        if (jsonMap.containsKey(fieldName)) {
          instance.setField(field.simpleName, jsonMap[fieldName]);
        }
      }
    }
    return instance.reflectee;
  }

  static List<Route> get routes => routesList;
}

/// Parses a query-string [value] into [targetType] (`int`, `double`, `bool` or
/// `String`), throwing [BadRequestException] when the value is not valid for the
/// requested type. Invalid client input becomes a 400, never a 500.
dynamic coerceParam(String name, String value, Type targetType) {
  if (targetType == int) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw BadRequestException('Query parameter "$name" must be an integer');
    }
    return parsed;
  }
  if (targetType == double) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw BadRequestException('Query parameter "$name" must be a number');
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
