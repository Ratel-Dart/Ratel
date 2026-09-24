import 'package:ratel/runtime.dart';

import '../controllers/cookie_response_controller.dart';

abstract final class CookieResponseControllerDefinition {
  static const value = ControllerDefinition<CookieResponseController>(
    create: CookieResponseController.new,
    routes: [
      RouteDefinition<CookieResponseController>(
        method: 'GET',
        path: '/sign-in',
        invoke: _signIn,
      ),
    ],
  );

  static Object? _signIn(
    CookieResponseController controller,
    List<Object?> arguments,
  ) =>
      controller.signIn();
}
