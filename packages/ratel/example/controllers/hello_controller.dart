import 'package:ratel/ratel.dart';

import '../dtos/greeting.dart';

@Controller()
class HelloController {
  @Get('/hello')
  Future<Greeting> hello(@Param() String? name) async =>
      Greeting(message: 'Hello, ${name ?? 'world'}!');

  @Get('/greet/:name')
  Future<Greeting> greet(@PathParam('name') String name) async =>
      Greeting(message: 'Hi, $name!');

  @Post('/echo')
  Future<Response<Greeting>> echo(@Body() Greeting body) async =>
      Response.json(statusCode: 201, data: body);
}
