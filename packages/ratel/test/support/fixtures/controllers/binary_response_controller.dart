import 'dart:convert';

import 'package:ratel/ratel.dart';

final class BinaryResponseController {
  Future<Response> bytes() async => Response.bytes(data: utf8.encode('hello'));
}
