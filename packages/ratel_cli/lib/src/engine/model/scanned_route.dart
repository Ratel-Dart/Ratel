import 'package:analyzer/dart/element/type.dart';

import 'scanned_parameter.dart';

final class ScannedRoute {
  const ScannedRoute({
    required this.methodName,
    required this.verb,
    required this.path,
    required this.isProtected,
    required this.roles,
    required this.parameters,
    required this.returnType,
  });

  final String methodName;
  final String verb;
  final String path;
  final bool isProtected;
  final List<String> roles;
  final List<ScannedParameter> parameters;
  final DartType returnType;
}
