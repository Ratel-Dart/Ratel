import 'dart:io';

import 'package:ratel/ratel.dart';

@Json()
class Greeting {
  String message;

  Greeting({this.message = ''});
}

class HelloController extends RatelHandler {
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

Future<void> main() async {
  final server = RatelServer(
    port: 8080,
    middlewares: [corsMiddleware(), securityHeadersMiddleware()],
  );

  await server.startServer();
  stdout.writeln('Ratel listening on http://localhost:8080');
  stdout.writeln('Try: curl "http://localhost:8080/hello?name=Ada"');
}
