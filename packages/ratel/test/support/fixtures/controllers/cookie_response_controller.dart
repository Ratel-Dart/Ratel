import 'dart:io';

import 'package:ratel/ratel.dart';

final class CookieResponseController {
  Future<Response> signIn() async =>
      Response.json(data: {'ok': true}).withCookie(
        Cookie('session', 'abc')
          ..httpOnly = true
          ..path = '/',
      );
}
