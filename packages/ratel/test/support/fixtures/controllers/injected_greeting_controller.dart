import 'package:ratel/ratel.dart';

import '../models/greeting_service.dart';

final class InjectedGreetingController {
  InjectedGreetingController(this.greeter);

  final GreetingService greeter;

  Future<Response> hello() async =>
      Response.json(data: {'greeting': greeter.greeting});
}
