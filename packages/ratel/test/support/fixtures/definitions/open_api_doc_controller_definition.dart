import 'package:ratel/runtime.dart';

import '../controllers/open_api_doc_controller.dart';
import '../models/new_user.dart';

abstract final class OpenApiDocControllerDefinition {
  static const value = ControllerDefinition<OpenApiDocController>(
    create: OpenApiDocController.new,
    routes: [
      RouteDefinition<OpenApiDocController>(
        method: 'GET',
        path: '/api/users/:id',
        parameters: [
          RouteParameter(
            name: 'id',
            location: ParameterLocation.path,
            type: int,
            isRequired: true,
          ),
          RouteParameter(
            name: 'format',
            location: ParameterLocation.query,
            type: String,
          ),
          RouteParameter(
            name: 'X-Trace',
            location: ParameterLocation.header,
            type: String,
          ),
        ],
        invoke: _byId,
      ),
      RouteDefinition<OpenApiDocController>(
        method: 'POST',
        path: '/api/users',
        isProtected: true,
        requiredRoles: ['admin'],
        parameters: [
          RouteParameter(
            name: 'body',
            location: ParameterLocation.body,
            type: NewUser,
            isRequired: true,
          ),
        ],
        invoke: _create,
      ),
    ],
  );

  static Object? _byId(
    OpenApiDocController controller,
    List<Object?> arguments,
  ) =>
      controller.byId(
        arguments[0] as int,
        arguments[1] as String?,
        arguments[2] as String?,
      );

  static Object? _create(
    OpenApiDocController controller,
    List<Object?> arguments,
  ) =>
      controller.create(arguments[0] as NewUser);
}
