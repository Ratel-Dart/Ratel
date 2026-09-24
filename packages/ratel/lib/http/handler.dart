import 'dart:io';

import '../annotations/annotations.dart';
import '../core/ratel_registry.dart';
import '../src/http/request_body_reader.dart';
import '../src/http/request_parameters.dart';
import 'socket_handler.dart';

abstract class RatelHandler {
  static void register(Route route) => RatelRegistry.current.register(route);

  static void registerSocket(String path, SocketHandler handler) =>
      RatelRegistry.current.registerSocket(path, handler);

  static SocketHandler? socketFor(String path) =>
      RatelRegistry.current.socketFor(path);

  static List<Route> get routes => RatelRegistry.current.routes;

  static int get maxRequestBodyBytes =>
      RatelRegistry.current.maxRequestBodyBytes;

  static int get maxBodyDrainBytes => RatelRegistry.current.maxBodyDrainBytes;

  static set maxBodyDrainBytes(int bytes) =>
      RatelRegistry.current.maxBodyDrainBytes = bytes;

  static void reset() => RatelRegistry.current.reset();
}

String? cookieValue(List<Cookie> cookies, String name) =>
    RequestParameters.cookieValue(cookies, name);

dynamic coerceParam(String name, String? value, Type targetType) =>
    RequestParameters.coerce(name, value, targetType);

Future<String> readBodyLimited(
  Stream<List<int>> stream,
  int maxBytes, {
  int? maxDrainBytes,
}) =>
    RequestBodyReader.readLimited(
      stream,
      maxBytes,
      maxDrainBytes: maxDrainBytes ?? RatelHandler.maxBodyDrainBytes,
    );

Map<String, dynamic> decodeBody(HttpRequest request, String body) =>
    RequestBodyReader.decode(request, body);

Map<String, dynamic> decodeJsonObject(String body) =>
    RequestBodyReader.decodeJsonObject(body);
