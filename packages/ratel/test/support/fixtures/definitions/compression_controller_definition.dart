import 'package:ratel/runtime.dart';

import '../controllers/compression_controller.dart';

abstract final class CompressionControllerDefinition {
  static const value = ControllerDefinition<CompressionController>(
    create: CompressionController.new,
    routes: [
      RouteDefinition<CompressionController>(
        method: 'GET',
        path: '/data',
        invoke: _data,
      ),
    ],
  );

  static Object? _data(
    CompressionController controller,
    List<Object?> arguments,
  ) =>
      controller.data();
}
