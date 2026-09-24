import 'package:ratel/runtime.dart';

import '../controllers/param_injection_controller.dart';

abstract final class ParamInjectionControllerDefinition {
  static const value = ControllerDefinition<ParamInjectionController>(
    create: ParamInjectionController.new,
    routes: [
      RouteDefinition<ParamInjectionController>(
        method: 'GET',
        path: '/header',
        parameters: [
          RouteParameter(
            name: 'X-User',
            location: ParameterLocation.header,
            type: String,
          ),
        ],
        invoke: _header,
      ),
      RouteDefinition<ParamInjectionController>(
        method: 'GET',
        path: '/cookie',
        parameters: [
          RouteParameter(
            name: 'session',
            location: ParameterLocation.cookie,
            type: String,
          ),
        ],
        invoke: _cookie,
      ),
    ],
  );

  static Object? _header(
    ParamInjectionController controller,
    List<Object?> arguments,
  ) =>
      controller.header(arguments[0] as String?);

  static Object? _cookie(
    ParamInjectionController controller,
    List<Object?> arguments,
  ) =>
      controller.cookie(arguments[0] as String?);
}
