import 'dart:io';
import 'dart:mirrors';

import '../dependency_injector/binding.dart';
import '../database/database.dart';
import '../annotations/geral_annotations.dart';
import '../handler/handler.dart';
import '../jwt.dart';
import 'response.dart';

class RatelServer {
  final int port;
  final RatelDatabase? database;
  final List<Type> handlers;
  final String? jwtKey;
  final Bindings? bindings;

  RatelServer({
    this.port = 8080,
    this.database,
    this.handlers = const [],
    this.jwtKey,
    this.bindings,
  }) {
    bindings?.dependencies();
    _initializeHandlers();
  }

  void _initializeHandlers() {
    for (var handlerType in handlers) {
      reflectClass(handlerType).newInstance(Symbol(''), []);
    }
  }

  Future<void> startServer() async {
    final jwtMiddleware = jwtKey != null ? JwtAuthMiddleware(jwtKey!) : null;
    var server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    await for (HttpRequest request in server) {
      String path = request.uri.path;
      String method = request.method;
      try {
        Route route = RatelHandler.routes.firstWhere(
          (r) => r.path == path && r.method == method,
        );

        if (jwtMiddleware != null && route.isProtected) {
          final payload = await jwtMiddleware.validate(request);
          if (payload == null) {
            Response(
              statusCode: HttpStatus.unauthorized,
              data: {'error': 'Token inválido ou ausente'},
            ).send(request.response);
            continue;
          }
        }

        final responseData = await route.handler(request);
        Response.from(responseData).send(request.response);
      } on StateError catch (e) {
        Response(
          statusCode: HttpStatus.notFound,
          data: {'error': '$e'},
        ).send(request.response);
      } catch (e) {
        Response(
          statusCode: HttpStatus.internalServerError,
          data: {'error': e.toString()},
        ).send(request.response);
      }
    }
  }
}
