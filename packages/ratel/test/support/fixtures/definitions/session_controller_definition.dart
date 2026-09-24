import 'package:ratel/runtime.dart';

import '../controllers/session_controller.dart';

abstract final class SessionControllerDefinition {
  static const value = ControllerDefinition<SessionController>(
    create: SessionController.new,
    routes: [
      RouteDefinition<SessionController>(
        method: 'GET',
        path: '/ping',
        invoke: _ping,
      ),
      RouteDefinition<SessionController>(
        method: 'GET',
        path: '/me',
        isProtected: true,
        parameters: [
          RouteParameter(
            name: 'ctx',
            location: ParameterLocation.context,
            type: RequestContext,
          ),
        ],
        invoke: _me,
      ),
      RouteDefinition<SessionController>(
        method: 'GET',
        path: '/explicit',
        invoke: _readExplicit,
      ),
      RouteDefinition<SessionController>(
        method: 'HEAD',
        path: '/explicit',
        invoke: _headExplicit,
      ),
    ],
  );

  static Object? _ping(SessionController controller, List<Object?> arguments) =>
      controller.ping();

  static Object? _me(SessionController controller, List<Object?> arguments) =>
      controller.me(arguments[0] as RequestContext);

  static Object? _readExplicit(
    SessionController controller,
    List<Object?> arguments,
  ) =>
      controller.readExplicit();

  static Object? _headExplicit(
    SessionController controller,
    List<Object?> arguments,
  ) =>
      controller.headExplicit();
}
