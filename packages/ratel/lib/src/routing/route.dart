import '../routing/route_parameter.dart';
import 'route_handler.dart';

final class Route {
  Route({
    required this.path,
    required this.method,
    required this.handler,
    this.isProtected = false,
    this.requiredRoles = const [],
    this.parameters = const [],
    this.bodyType,
  });

  final String path;
  final String method;
  final RouteHandler handler;
  final bool isProtected;
  final List<String> requiredRoles;
  final List<RouteParameter> parameters;
  final String? bodyType;
}
