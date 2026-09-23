import 'package:analyzer/dart/element/element.dart';

import 'annotation_checkers.dart';
import 'constant_values.dart';
import 'type_display.dart';

/// Emits the `parameters:` list a `Route` carries, describing every input the
/// handler reads so the routes can be documented without reflection.
String emitRouteParameters(MethodElement method) {
  final entries = method.formalParameters.map(_emitParameter).nonNulls.toList();
  if (entries.isEmpty) return '    parameters: const [],';
  return '    parameters: const [\n${entries.join('\n')}\n    ],';
}

/// Emits the `bodyType:` of a route: the name of the `@Json` class bound to its
/// `@Body` parameter, or `null` when it takes no body.
String emitRouteBodyType(MethodElement method) {
  for (final param in method.formalParameters) {
    if (bodyChecker.hasAnnotationOf(param)) {
      return "    bodyType: '${nonNullableDisplay(param.type)}',";
    }
  }
  return '    bodyType: null,';
}

String? _emitParameter(FormalParameterElement param) {
  final path = pathParamChecker.firstAnnotationOf(param);
  if (path != null) {
    return _parameter(readString(path, 'name')!, 'path', param, true);
  }
  if (paramChecker.hasAnnotationOf(param)) {
    return _parameter(param.displayName, 'query', param, null);
  }
  final header = headerChecker.firstAnnotationOf(param);
  if (header != null) {
    return _parameter(readString(header, 'name')!, 'header', param, null);
  }
  final cookie = cookieChecker.firstAnnotationOf(param);
  if (cookie != null) {
    return _parameter(readString(cookie, 'name')!, 'cookie', param, null);
  }
  return null;
}

String _parameter(
  String name,
  String location,
  FormalParameterElement param,
  bool? required,
) {
  final isRequired = required ?? !isNullableType(param.type);
  return "      _r.RouteParameter(\n"
      "        name: '$name',\n"
      '        location: _r.ParameterLocation.$location,\n'
      '        type: ${nonNullableDisplay(param.type)},\n'
      '        isRequired: $isRequired,\n'
      '      ),';
}
