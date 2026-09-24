import 'package:ratel/ratel.dart';

final class WidgetsController {
  Future<Response> list() async => Response.json(data: {'widgets': []});

  Future<Response> describe() async =>
      Response.json(data: {'methods': 'GET, OPTIONS'});
}
