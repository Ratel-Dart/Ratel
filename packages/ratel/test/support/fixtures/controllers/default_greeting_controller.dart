import 'package:ratel/ratel.dart';

final class DefaultGreetingController {
  Future<Response> hello() async =>
      Response.json(data: {'greeting': 'default'});
}
