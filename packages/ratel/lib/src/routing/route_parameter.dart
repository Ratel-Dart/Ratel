import 'parameter_location.dart';

class RouteParameter {
  final String name;

  final ParameterLocation location;

  final Type type;

  final bool isRequired;

  const RouteParameter({
    required this.name,
    required this.location,
    required this.type,
    this.isRequired = false,
  });
}
