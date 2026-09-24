import 'package:ratel/runtime.dart';

import '../controllers/greeter_controller.dart';

abstract final class GreeterControllerDefinition {
  static const value = ControllerDefinition<GreeterController>(
    routes: [
      RouteDefinition<GreeterController>(
        method: 'GET',
        path: '/greet',
        invoke: _greet,
      ),
    ],
  );

  static Object? _greet(
          GreeterController controller, List<Object?> arguments) =>
      controller.greet();
}
