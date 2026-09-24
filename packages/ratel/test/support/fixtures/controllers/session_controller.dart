import 'dart:io';

import 'package:ratel/ratel.dart';

final class SessionController {
  Future<Response> ping() async => Response.json(data: {'ok': true});

  Future<Response> me(RequestContext ctx) async =>
      Response.json(data: {'sub': ctx.claims?['sub'], 'path': ctx.path});

  Future<Response> readExplicit() async => Response.json(data: {'kind': 'get'});

  Future<Response> headExplicit() async => Response(
        statusCode: HttpStatus.noContent,
        headers: const {'X-Kind': 'head'},
      );
}
