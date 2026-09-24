import 'dart:io';

import 'package:ratel/ratel.dart';

import '../models/plain_value.dart';

final class ResponseBodyController {
  Future<Response> unencodable() async => Response.json(data: PlainValue());

  Future<Response> emptyText() async => Response.text();

  Future<Response> charsetJson() async => Response(
        statusCode: HttpStatus.ok,
        data: {'ok': true},
        contentType: 'application/json; charset=utf-8',
      );
}
