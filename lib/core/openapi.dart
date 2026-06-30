import 'dart:mirrors';

import '../annotations/annotations.dart';

/// Builds an [OpenAPI 3](https://spec.openapis.org/oas/v3.0.0) document from the
/// registered [routes] (typically `RatelHandler.routes`).
///
/// Path parameters (`:id`) become `{id}`, `@Param`/`@PathParam`/`@Header`
/// arguments become operation parameters, `@Body` arguments become a JSON
/// request body, and `@Protected` routes carry a `bearerAuth` security
/// requirement. Serve the result from a route, e.g.
/// `Response.json(data: openApiSpec(RatelHandler.routes))`.
Map<String, dynamic> openApiSpec(
  List<Route> routes, {
  String title = 'API',
  String version = '1.0.0',
}) {
  final paths = <String, dynamic>{};
  for (final route in routes) {
    final pathItem = (paths[_toOpenApiPath(route.path)] ??= <String, dynamic>{})
        as Map<String, dynamic>;

    final operation = <String, dynamic>{
      'responses': {
        '200': {'description': 'OK'},
      },
    };
    final parameters = _parameters(route);
    if (parameters.isNotEmpty) operation['parameters'] = parameters;
    if (_hasBody(route)) {
      operation['requestBody'] = {
        'content': {
          'application/json': {
            'schema': {'type': 'object'},
          },
        },
      };
    }
    if (route.isProtected) {
      operation['security'] = [
        {'bearerAuth': <String>[]},
      ];
    }
    pathItem[route.method.toLowerCase()] = operation;
  }

  return {
    'openapi': '3.0.0',
    'info': {'title': title, 'version': version},
    'paths': paths,
    'components': {
      'securitySchemes': {
        'bearerAuth': {
          'type': 'http',
          'scheme': 'bearer',
          'bearerFormat': 'JWT',
        },
      },
    },
  };
}

String _toOpenApiPath(String path) {
  return path
      .split('/')
      .map((segment) =>
          segment.startsWith(':') ? '{${segment.substring(1)}}' : segment)
      .join('/');
}

List<Map<String, dynamic>> _parameters(Route route) {
  final method = route.methodMirror;
  if (method == null) return const [];
  final parameters = <Map<String, dynamic>>[];
  for (final param in method.parameters) {
    for (final meta in param.metadata) {
      final reflectee = meta.reflectee;
      if (reflectee is PathParam) {
        parameters.add({
          'name': reflectee.name,
          'in': 'path',
          'required': true,
          'schema': {'type': _schemaType(param.type.reflectedType)},
        });
      } else if (reflectee is Param) {
        parameters.add({
          'name': MirrorSystem.getName(param.simpleName),
          'in': 'query',
          'required': false,
          'schema': {'type': _schemaType(param.type.reflectedType)},
        });
      } else if (reflectee is Header) {
        parameters.add({
          'name': reflectee.name,
          'in': 'header',
          'required': false,
          'schema': {'type': 'string'},
        });
      }
    }
  }
  return parameters;
}

bool _hasBody(Route route) {
  final method = route.methodMirror;
  if (method == null) return false;
  return method.parameters
      .any((p) => p.metadata.any((m) => m.reflectee is Body));
}

String _schemaType(Type type) {
  if (type == int) return 'integer';
  if (type == double || type == num) return 'number';
  if (type == bool) return 'boolean';
  return 'string';
}
