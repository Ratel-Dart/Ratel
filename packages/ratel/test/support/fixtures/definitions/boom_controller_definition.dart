import 'package:ratel/runtime.dart';

import '../controllers/boom_controller.dart';

abstract final class BoomControllerDefinition {
  static const value = ControllerDefinition<BoomController>(
    create: BoomController.new,
    routes: [
      RouteDefinition<BoomController>(
        method: 'GET',
        path: '/boom',
        invoke: _boom,
      ),
    ],
  );

  static Object? _boom(BoomController controller, List<Object?> arguments) =>
      controller.boom();
}
