import 'scanned_parameter.dart';

final class ScannedSocket {
  const ScannedSocket({
    required this.methodName,
    required this.path,
    required this.isProtected,
    required this.roles,
    required this.parameters,
  });

  final String methodName;
  final String path;
  final bool isProtected;
  final List<String> roles;
  final List<ScannedParameter> parameters;
}
