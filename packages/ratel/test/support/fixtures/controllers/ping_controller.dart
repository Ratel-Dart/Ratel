import 'package:ratel/ratel.dart';

final class PingController {
  Future<Response> ping() async => Response.json(data: {'ok': true});
}
