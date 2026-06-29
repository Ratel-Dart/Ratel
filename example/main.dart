import 'dart:io';

import 'package:ratel/ratel.dart';

/// A JSON-serializable model. The [Json] annotation lets Ratel deserialize it
/// from a request body and serialize it back into a response.
@Json()
class Greeting {
  String message;

  Greeting({this.message = ''});
}

/// A controller exposes routes by annotating methods. Each method returns a
/// [Response] (or any value, which is wrapped as JSON).
class HelloController extends RatelHandler {
  /// GET /hello?name=Ada  ->  {"message":"Hello, Ada!"}
  @Get('/hello')
  Future<Response> hello(@Param() String? name) async {
    return Response.json(
      statusCode: HttpStatus.ok,
      data: Greeting(message: 'Hello, ${name ?? 'world'}!'),
    );
  }

  /// POST /echo  with body {"message":"hi"}  ->  {"message":"hi"}
  @Post('/echo')
  Future<Response> echo(@Body() Greeting body) async {
    return Response.json(statusCode: HttpStatus.ok, data: body);
  }
}

Future<void> main() async {
  final server = RatelServer(
    port: 8080,
    handlers: [HelloController],
    middlewares: [corsMiddleware(), securityHeadersMiddleware()],
  );

  await server.startServer();
  stdout.writeln('Ratel listening on http://localhost:8080');
  stdout.writeln('Try: curl "http://localhost:8080/hello?name=Ada"');
}
