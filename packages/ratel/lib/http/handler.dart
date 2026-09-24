import 'dart:convert';
import 'dart:io';

import '../annotations/annotations.dart';
import '../core/ratel_registry.dart';
import '../exceptions/exceptions.dart';
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

String? cookieValue(List<Cookie> cookies, String name) {
  for (final cookie in cookies) {
    if (cookie.name == name) return cookie.value;
  }
  return null;
}

dynamic coerceParam(String name, String? value, Type targetType) {
  if (value == null) return null;
  if (targetType == int) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw BadRequestException('Parameter "$name" must be an integer');
    }
    return parsed;
  }
  if (targetType == double) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw BadRequestException('Parameter "$name" must be a number');
    }
    return parsed;
  }
  if (targetType == bool) {
    return value.toLowerCase() == 'true';
  }
  return value;
}

Future<String> readBodyLimited(
  Stream<List<int>> stream,
  int maxBytes, {
  int? maxDrainBytes,
}) async {
  final drainLimit = maxDrainBytes ?? RatelHandler.maxBodyDrainBytes;
  final bytes = <int>[];
  var total = 0;
  var discarded = 0;
  var drained = true;
  await for (final chunk in stream) {
    total += chunk.length;
    if (total > maxBytes) {
      discarded += chunk.length;
      if (discarded > drainLimit) {
        drained = false;
        break;
      }
      continue;
    }
    bytes.addAll(chunk);
  }
  if (total > maxBytes) {
    throw PayloadTooLargeException(
      'Request body exceeds the limit of $maxBytes bytes',
      drained ? const {} : const {HttpHeaders.connectionHeader: 'close'},
    );
  }
  return utf8.decode(bytes);
}

Map<String, dynamic> decodeBody(HttpRequest request, String body) {
  final mimeType = request.headers.contentType?.mimeType;
  if (mimeType == 'application/x-www-form-urlencoded') {
    return Map<String, dynamic>.from(Uri.splitQueryString(body));
  }
  return decodeJsonObject(body);
}

Map<String, dynamic> decodeJsonObject(String body) {
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw BadRequestException('Request body is not valid JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw BadRequestException('Request body must be a JSON object');
  }
  return decoded;
}
