import 'package:ratel/ratel.dart';

final class SecuredApiController {
  Future<Response> public() async => Response.json(data: {'ok': true});

  Future<Response> secure() async => Response.json(data: {'ok': true});

  Future<Response> admin() async => Response.json(data: {'ok': true});
}
