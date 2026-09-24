import 'package:ratel/runtime.dart';

import '../controllers/response_body_controller.dart';

abstract final class ResponseBodyControllerDefinition {
  static const value = ControllerDefinition<ResponseBodyController>(
    create: ResponseBodyController.new,
    routes: [
      RouteDefinition<ResponseBodyController>(
        method: 'GET',
        path: '/unencodable',
        invoke: _unencodable,
      ),
      RouteDefinition<ResponseBodyController>(
        method: 'GET',
        path: '/empty-text',
        invoke: _emptyText,
      ),
      RouteDefinition<ResponseBodyController>(
        method: 'GET',
        path: '/charset-json',
        invoke: _charsetJson,
      ),
    ],
  );

  static Object? _unencodable(
    ResponseBodyController controller,
    List<Object?> arguments,
  ) =>
      controller.unencodable();

  static Object? _emptyText(
    ResponseBodyController controller,
    List<Object?> arguments,
  ) =>
      controller.emptyText();

  static Object? _charsetJson(
    ResponseBodyController controller,
    List<Object?> arguments,
  ) =>
      controller.charsetJson();
}
