import 'package:ratel/ratel.dart';

import '../models/greeting.dart';

@Controller()
class HelloController {
  @Get('/hello')
  Future<Response> hello(@Param() String? name) async {
    return Response.json(data: Greeting(message: 'Hello, ${name ?? 'world'}!'));
  }

  @Get('/greet/:name')
  Future<Response> greet(@PathParam('name') String name) async {
    return Response.json(data: Greeting(message: 'Hi, $name!'));
  }

  @Post('/echo')
  Future<Response> echo(@Body() Greeting body) async {
    return Response.json(data: body);
  }
}
