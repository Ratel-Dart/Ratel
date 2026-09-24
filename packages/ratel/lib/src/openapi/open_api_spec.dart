import '../annotations/annotations.dart';
import '../routing/route_parameter.dart';

Map<String, dynamic> openApiSpec(
  List<Route> routes, {
  String title = 'API',
  String version = '1.0.0',
}) {
  final paths = <String, dynamic>{};
  for (final route in routes) {
    final item = (paths[_openApiPath(route.path)] ??= <String, dynamic>{})
        as Map<String, dynamic>;
    item[route.method.toLowerCase()] = _operation(route);
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

Map<String, dynamic> _operation(Route route) {
  final operation = <String, dynamic>{
    'responses': {
      '200': {'description': 'OK'},
    },
  };

  if (route.parameters.isNotEmpty) {
    operation['parameters'] = route.parameters.map(_parameter).toList();
  }

  final bodyType = route.bodyType;
  if (bodyType != null) {
    operation['requestBody'] = {
      'required': true,
      'content': {
        'application/json': {
          'schema': {'type': 'object', 'title': bodyType},
        },
      },
    };
  }

  if (route.isProtected) {
    operation['security'] = [
      {'bearerAuth': route.requiredRoles},
    ];
  }

  return operation;
}

Map<String, dynamic> _parameter(RouteParameter parameter) => {
      'name': parameter.name,
      'in': parameter.location.name,
      'required': parameter.isRequired,
      'schema': {'type': _schemaType(parameter.type)},
    };

String _openApiPath(String path) => path
    .split('/')
    .map((s) => s.startsWith(':') ? '{${s.substring(1)}}' : s)
    .join('/');

String _schemaType(Type type) {
  if (type == int) return 'integer';
  if (type == double || type == num) return 'number';
  if (type == bool) return 'boolean';
  return 'string';
}
