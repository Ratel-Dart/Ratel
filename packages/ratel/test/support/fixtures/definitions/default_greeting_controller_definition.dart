import 'package:ratel/runtime.dart';

import '../controllers/default_greeting_controller.dart';

abstract final class DefaultGreetingControllerDefinition {
  static const value = ControllerDefinition<DefaultGreetingController>(
    create: DefaultGreetingController.new,
    routes: [
      RouteDefinition<DefaultGreetingController>(
        method: 'GET',
        path: '/plain/hello',
        invoke: _hello,
      ),
    ],
  );

  static Object? _hello(
    DefaultGreetingController controller,
    List<Object?> arguments,
  ) =>
      controller.hello();
}
