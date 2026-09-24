import 'dart:io';

import 'package:ratel/ratel.dart';

Future<void> main() async {
  final server = RatelServer(
    port: 8080,
    middlewares: [CorsMiddleware.create(), SecurityHeadersMiddleware.create()],
  );

  await server.startServer();
  stdout.writeln('Ratel listening on http://localhost:8080');
  stdout.writeln('Try: curl "http://localhost:8080/hello?name=Ada"');
}
