import '../binding/route_binder.dart';
import 'route_definition.dart';
import 'socket_definition.dart';

final class ControllerDefinition<C extends Object> {
  const ControllerDefinition({
    this.create,
    this.routes = const [],
    this.sockets = const [],
  });

  final C Function()? create;
  final List<RouteDefinition<C>> routes;
  final List<SocketDefinition<C>> sockets;

  Type get type => C;

  void bindWith(RouteBinder binder) => binder.bind<C>(this);
}
