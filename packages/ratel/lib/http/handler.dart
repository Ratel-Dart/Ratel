import 'dart:convert';
import 'dart:io';

import '../annotations/annotations.dart';
import '../core/ratel_registry.dart';
import '../exceptions/exceptions.dart';
import 'socket_handler.dart';

/// Base class for controllers. Subclasses annotate methods with `@Get`,
/// `@Post`, etc.; a class-level `@Controller('/prefix')` prefixes every route.
///
/// Routes are registered by generated code (`$registerRatel()`, which the
/// `ratel` CLI wires into the application bootstrap), so a controller needs no
/// registration boilerplate of its own.
abstract class RatelHandler {
  /// Registers [route] on the ambient [RatelRegistry].
  static void register(Route route) => RatelRegistry.current.register(route);

  /// Registers [handler] for WebSocket upgrades on [path] on the ambient
  /// [RatelRegistry].
  static void registerSocket(String path, SocketHandler handler) =>
      RatelRegistry.current.registerSocket(path, handler);

  /// The handler accepting WebSocket upgrades on [path] on the ambient
  /// [RatelRegistry].
  static SocketHandler? socketFor(String path) =>
      RatelRegistry.current.socketFor(path);

  /// Routes registered on the ambient [RatelRegistry].
  static List<Route> get routes => RatelRegistry.current.routes;

  /// Maximum accepted request body size on the ambient [RatelRegistry].
  ///
  /// A handler reads its server's limit from `ctx.registry` instead, so two
  /// servers in one isolate do not share one.
  static int get maxRequestBodyBytes =>
      RatelRegistry.current.maxRequestBodyBytes;

  /// How many bytes past [maxRequestBodyBytes] are read and discarded before a
  /// rejected request is abandoned, on the ambient [RatelRegistry]. See
  /// [readBodyLimited].
  static int get maxBodyDrainBytes => RatelRegistry.current.maxBodyDrainBytes;

  static set maxBodyDrainBytes(int bytes) =>
      RatelRegistry.current.maxBodyDrainBytes = bytes;

  /// Empties the ambient [RatelRegistry]. Intended for tests that register
  /// routes more than once in a single isolate.
  static void reset() => RatelRegistry.current.reset();
}

/// Returns the value of the cookie named [name], or null when absent.
String? cookieValue(List<Cookie> cookies, String name) {
  for (final cookie in cookies) {
    if (cookie.name == name) return cookie.value;
  }
  return null;
}

/// Parses a query/path/header/cookie [value] into [targetType] (`int`,
/// `double`, `bool` or `String`), throwing [BadRequestException] when the value
/// is not valid for the requested type. Returns null when [value] is null.
/// Invalid client input becomes a 400, never a 500.
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

/// Reads the full request body from [stream] as a UTF-8 string, rejecting
/// bodies larger than [maxBytes] with a [PayloadTooLargeException]. Counting
/// bytes as they arrive bounds memory even for chunked requests whose length is
/// unknown in advance.
///
/// Bytes past the limit are still read, and discarded, up to
/// [RatelHandler.maxBodyDrainBytes]. `dart:io` resets a connection whose
/// request body was left unread, which would tear the socket down before the
/// client could read the 413; draining lets the request finish cleanly so the
/// response is delivered and the connection stays reusable. A body that
/// overshoots even that much is abandoned, and the exception carries
/// `Connection: close` — delivery of that response is best-effort.
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

/// Decodes a request [body] into a map based on its `Content-Type`: JSON
/// objects (the default) or `application/x-www-form-urlencoded` form fields
/// (whose values are always strings).
Map<String, dynamic> decodeBody(HttpRequest request, String body) {
  final mimeType = request.headers.contentType?.mimeType;
  if (mimeType == 'application/x-www-form-urlencoded') {
    return Map<String, dynamic>.from(Uri.splitQueryString(body));
  }
  return decodeJsonObject(body);
}

/// Decodes [body] as a JSON object, throwing [BadRequestException] (400) for
/// invalid JSON or for a non-object top-level value (e.g. an array). This keeps
/// malformed client input from surfacing as a 500.
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
