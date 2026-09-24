import 'package:ratel/runtime.dart';

import '../controllers/widgets_controller.dart';

abstract final class WidgetsControllerDefinition {
  static const value = ControllerDefinition<WidgetsController>(
    create: WidgetsController.new,
    routes: [
      RouteDefinition<WidgetsController>(
        method: 'GET',
        path: '/widgets',
        invoke: _list,
      ),
      RouteDefinition<WidgetsController>(
        method: 'OPTIONS',
        path: '/widgets',
        invoke: _describe,
      ),
    ],
  );

  static Object? _list(WidgetsController controller, List<Object?> arguments) =>
      controller.list();

  static Object? _describe(
    WidgetsController controller,
    List<Object?> arguments,
  ) =>
      controller.describe();
}
