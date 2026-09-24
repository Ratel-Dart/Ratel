import 'package:ratel/runtime.dart';

import '../controllers/injected_greeting_controller.dart';

abstract final class InjectedGreetingControllerDefinition {
  static const value = ControllerDefinition<InjectedGreetingController>(
    routes: [
      RouteDefinition<InjectedGreetingController>(
        method: 'GET',
        path: '/di/hello',
        invoke: _hello,
      ),
    ],
  );

  static Object? _hello(
    InjectedGreetingController controller,
    List<Object?> arguments,
  ) =>
      controller.hello();
}
