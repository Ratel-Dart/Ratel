import 'dart:io';

import 'ratel_handler.dart';
import 'ratel_response.dart';
import 'ratel_route.dart';

class RatelServer {
  int port;

  RatelServer({this.port = 8080});

  Future<void> startServer() async {
    var server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    await for (HttpRequest request in server) {
      String path = request.uri.path;
      String method = request.method;

      try {
        Route route = RatelHandler.routes.firstWhere(
          (route) => route.path == path && route.method == method,
        );

        dynamic retorno = route.handler();
        Response.from(retorno).send(request.response);
      } catch (e) {
        Response(
          statusCode: HttpStatus.notFound,
          data: {'error': 'Rota não encontrada'},
        ).send(request.response);
      }
    }
  }
}
