import '../routing/route_parameter.dart';
import 'controller_invoker.dart';

final class SocketDefinition<C> {
  const SocketDefinition({
    required this.path,
    required this.invoke,
    this.isProtected = false,
    this.requiredRoles = const [],
    this.parameters = const [],
  });

  final String path;
  final bool isProtected;
  final List<String> requiredRoles;
  final List<RouteParameter> parameters;
  final ControllerInvoker<C> invoke;
}
