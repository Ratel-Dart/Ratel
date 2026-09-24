import '../../core/route_parameter.dart';
import 'controller_invoker.dart';

final class SocketDefinition<C> {
  const SocketDefinition({
    required this.path,
    required this.invoke,
    this.parameters = const [],
  });

  final String path;
  final List<RouteParameter> parameters;
  final ControllerInvoker<C> invoke;
}
