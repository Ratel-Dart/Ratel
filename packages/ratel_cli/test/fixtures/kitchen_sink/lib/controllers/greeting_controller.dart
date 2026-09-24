import 'package:ratel/ratel.dart';

import '../models/greeter.dart';

@Controller('/greet')
class GreetingController {
  GreetingController(this.greeter);

  final Greeter greeter;

  @Get('')
  Future<Response> greet({@Param() String? name}) async =>
      Response.text(data: '${greeter.salutation}, ${name ?? 'world'}');
}
