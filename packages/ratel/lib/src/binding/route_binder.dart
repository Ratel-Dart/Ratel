import '../dependency_injector/injector.dart';
import '../routing/parameter_location.dart';
import '../routing/route.dart';
import '../routing/route_parameter.dart';
import '../runtime/controller_definition.dart';
import '../server/ratel_registry.dart';
import 'argument_resolver.dart';

final class RouteBinder {
  RouteBinder(this.registry);

  final RatelRegistry registry;

  void bind<C extends Object>(ControllerDefinition<C> definition) {
    C? instance;
    C controller() => instance ??= _create(definition);
    registry.registerControllerCheck(() => _ensureCreatable(definition));

    for (final route in definition.routes) {
      registry.register(Route(
        path: route.path,
        method: route.method,
        isProtected: route.isProtected,
        requiredRoles: route.requiredRoles,
        parameters: [
          for (final parameter in route.parameters)
            if (_isRequestParameter(parameter)) parameter,
        ],
        bodyType: _bodyType(route.parameters),
        handler: (ctx) async {
          final arguments = await ArgumentResolver.resolve(
            route.parameters,
            ctx,
            registry.codecs,
          );
          return await route.invoke(controller(), arguments);
        },
      ));
    }

    for (final socket in definition.sockets) {
      registry.registerSocket(socket.path, (webSocket, ctx) async {
        final arguments = ArgumentResolver.resolveSocket(
          socket.parameters,
          webSocket,
          ctx,
        );
        await socket.invoke(controller(), arguments);
      });
    }
  }

  static C _create<C extends Object>(ControllerDefinition<C> definition) {
    final injector = Injector();
    if (injector.contains<C>()) return injector.get<C>();
    final create = definition.create;
    if (create != null) return create();
    throw StateError(_unregistered(C));
  }

  static void _ensureCreatable<C extends Object>(
    ControllerDefinition<C> definition,
  ) {
    if (Injector().contains<C>() || definition.create != null) return;
    throw StateError(_unregistered(C));
  }

  static String _unregistered(Type controller) =>
      'Controller $controller has no constructor Ratel can call without '
      'arguments. Register it in Bindings.dependencies() with '
      'Injector().put<$controller>(() => $controller(...)).';

  static bool _isRequestParameter(RouteParameter parameter) =>
      switch (parameter.location) {
        ParameterLocation.path ||
        ParameterLocation.query ||
        ParameterLocation.header ||
        ParameterLocation.cookie =>
          true,
        _ => false,
      };

  static String? _bodyType(List<RouteParameter> parameters) {
    for (final parameter in parameters) {
      if (parameter.location == ParameterLocation.body) {
        return parameter.type.toString();
      }
    }
    return null;
  }
}
