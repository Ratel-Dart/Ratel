import 'package:ratel/runtime.dart';

import '../controllers/secured_api_controller.dart';

abstract final class SecuredApiControllerDefinition {
  static const value = ControllerDefinition<SecuredApiController>(
    create: SecuredApiController.new,
    routes: [
      RouteDefinition<SecuredApiController>(
        method: 'GET',
        path: '/public',
        invoke: _public,
      ),
      RouteDefinition<SecuredApiController>(
        method: 'GET',
        path: '/secure',
        isProtected: true,
        invoke: _secure,
      ),
      RouteDefinition<SecuredApiController>(
        method: 'GET',
        path: '/admin',
        isProtected: true,
        requiredRoles: ['admin'],
        invoke: _admin,
      ),
    ],
  );

  static Object? _public(
    SecuredApiController controller,
    List<Object?> arguments,
  ) =>
      controller.public();

  static Object? _secure(
    SecuredApiController controller,
    List<Object?> arguments,
  ) =>
      controller.secure();

  static Object? _admin(
    SecuredApiController controller,
    List<Object?> arguments,
  ) =>
      controller.admin();
}
