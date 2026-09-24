import 'package:ratel/runtime.dart';

import '../controllers/binary_response_controller.dart';

abstract final class BinaryResponseControllerDefinition {
  static const value = ControllerDefinition<BinaryResponseController>(
    create: BinaryResponseController.new,
    routes: [
      RouteDefinition<BinaryResponseController>(
        method: 'GET',
        path: '/bytes',
        invoke: _bytes,
      ),
    ],
  );

  static Object? _bytes(
    BinaryResponseController controller,
    List<Object?> arguments,
  ) =>
      controller.bytes();
}
