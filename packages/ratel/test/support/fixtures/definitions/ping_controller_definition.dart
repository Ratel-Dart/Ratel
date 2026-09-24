import 'package:ratel/runtime.dart';

import '../controllers/ping_controller.dart';

abstract final class PingControllerDefinition {
  static const value = ControllerDefinition<PingController>(
    create: PingController.new,
    routes: [
      RouteDefinition<PingController>(
        method: 'GET',
        path: '/ping',
        invoke: _ping,
      ),
    ],
  );

  static Object? _ping(PingController controller, List<Object?> arguments) =>
      controller.ping();
}
