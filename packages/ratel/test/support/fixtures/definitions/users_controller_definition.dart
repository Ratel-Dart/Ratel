import 'package:ratel/runtime.dart';

import '../controllers/users_controller.dart';
import '../models/user_patch.dart';

abstract final class UsersControllerDefinition {
  static const value = ControllerDefinition<UsersController>(
    create: UsersController.new,
    routes: [
      RouteDefinition<UsersController>(
        method: 'GET',
        path: '/api/users/:id',
        parameters: [
          RouteParameter(
            name: 'id',
            location: ParameterLocation.path,
            type: int,
            isRequired: true,
          ),
        ],
        invoke: _getUser,
      ),
      RouteDefinition<UsersController>(
        method: 'PATCH',
        path: '/api/users/:id',
        parameters: [
          RouteParameter(
            name: 'id',
            location: ParameterLocation.path,
            type: int,
            isRequired: true,
          ),
          RouteParameter(
            name: 'body',
            location: ParameterLocation.body,
            type: UserPatch,
            isRequired: true,
          ),
        ],
        invoke: _patchUser,
      ),
      RouteDefinition<UsersController>(
        method: 'POST',
        path: '/api/users',
        invoke: _create,
      ),
    ],
  );

  static Object? _getUser(
          UsersController controller, List<Object?> arguments) =>
      controller.getUser(arguments[0] as int);

  static Object? _patchUser(
    UsersController controller,
    List<Object?> arguments,
  ) =>
      controller.patchUser(arguments[0] as int, arguments[1] as UserPatch);

  static Object? _create(UsersController controller, List<Object?> arguments) =>
      controller.create();
}
