import 'dart:io';
import 'dart:mirrors';

import '../database/database.dart';
import '../annotations/geral_annotations.dart';
import '../handler/handler.dart';
import 'response.dart';

class RatelServer {
  final int port;
  final RatelDatabase? database;
  final handlers;

  RatelServer({
    this.port = 8080,
    this.database,
    this.handlers = const [],
  }) {
    initializeHandlers();
  }

  Future<void> startServer() async {
    var server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    await for (HttpRequest request in server) {
      String path = request.uri.path;
      String method = request.method;

      try {
        Route route = RatelHandler.routes.firstWhere(
          (route) => route.path == path && route.method == method,
        );

        dynamic response = await route.handler(request);
        Response.from(response).send(request.response);
      } catch (e) {
        Response(
          statusCode: HttpStatus.internalServerError,
          data: {'error': e.toString()},
        ).send(request.response);
      }
    }
  }

  void initializeHandlers() {
    for (var handlerType in handlers) {
      ClassMirror classMirror = reflectClass(handlerType);
      classMirror.newInstance(Symbol(''), []);
    }
  }
}
