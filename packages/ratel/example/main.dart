import 'dart:io';

import 'package:ratel/ratel.dart';

/// A JSON-serializable model. The [Json] annotation generates its serializer
/// and deserializer, so neither `toJson` nor `fromJson` is written by hand.
@Json()
class Greeting {
  String message;

  Greeting({this.message = ''});
}

/// A controller exposes routes by annotating methods. Each method returns a
/// [Response] (or any value, which is wrapped as JSON). Routes are registered
/// by generated code, so the controller carries no wiring of its own.
///
/// Run with `ratel dev`, which generates the wiring and starts the server.
class HelloController extends RatelHandler {
  /// GET /hello?name=Ada  ->  {"message":"Hello, Ada!"}
  @Get('/hello')
  Future<Response> hello(@Param() String? name) async {
    return Response.json(data: Greeting(message: 'Hello, ${name ?? 'world'}!'));
  }

  /// GET /greet/Ada  ->  {"message":"Hi, Ada!"}
  @Get('/greet/:name')
  Future<Response> greet(@PathParam('name') String name) async {
    return Response.json(data: Greeting(message: 'Hi, $name!'));
  }

  /// POST /echo  with body {"message":"hi"}  ->  {"message":"hi"}
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
