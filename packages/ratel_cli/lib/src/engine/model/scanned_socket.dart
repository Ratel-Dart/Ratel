import 'scanned_parameter.dart';

final class ScannedSocket {
  const ScannedSocket({
    required this.methodName,
    required this.path,
    required this.parameters,
  });

  final String methodName;
  final String path;
  final List<ScannedParameter> parameters;
}
