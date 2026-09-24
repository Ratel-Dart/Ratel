import '../routing/route_parameter.dart';
import 'controller_invoker.dart';

final class RouteDefinition<C> {
  const RouteDefinition({
    required this.method,
    required this.path,
    required this.invoke,
    this.isProtected = false,
    this.requiredRoles = const [],
    this.parameters = const [],
  });

  final String method;
  final String path;
  final bool isProtected;
  final List<String> requiredRoles;
  final List<RouteParameter> parameters;
  final ControllerInvoker<C> invoke;
}
