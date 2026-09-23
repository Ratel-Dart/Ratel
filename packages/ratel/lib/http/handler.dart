import 'dart:convert';
import 'dart:io';

import '../annotations/annotations.dart';
import '../core/router.dart';
import '../exceptions/exceptions.dart';
import 'socket_handler.dart';

/// Base class for controllers. Subclasses annotate methods with `@Get`,
/// `@Post`, etc.; a class-level `@Controller('/prefix')` prefixes every route.
///
/// Routes are registered by generated code (`$registerRatel()`, which the
/// `ratel` CLI wires into the application bootstrap), so a controller needs no
/// registration boilerplate of its own.
abstract class RatelHandler {
  static final List<Route> routesList = [];

  /// WebSocket handlers registered from @Socket methods, keyed by their
  /// normalised path.
  static final Map<String, SocketHandler> socketRoutesMap = {};

  /// Maximum accepted request body size, in bytes. Bodies larger than this are
  /// rejected with `413 Payload Too Large`. Configured via
  /// `RatelServer(maxRequestBodyBytes: ...)`; defaults to 1 MiB.
  static int maxRequestBodyBytes = 1024 * 1024;

  /// Registers [route], rejecting a duplicate `method`+`path` pair.
  static void register(Route route) {
    final clash = routesList.any(
      (r) => r.path == route.path && r.method == route.method,
    );
    if (clash) {
      throw StateError(
        'Duplicate route registered: ${route.method} ${route.path}',
      );
    }
    routesList.add(route);
  }

  /// Registers [handler] for WebSocket upgrades on [path], rejecting a second
  /// registration for the same path.
  static void registerSocket(String path, SocketHandler handler) {
    final key = normaliseSocketPath(path);
    if (socketRoutesMap.containsKey(key)) {
      throw StateError('Duplicate socket registered: $key');
    }
    socketRoutesMap[key] = handler;
  }

  /// The handler accepting WebSocket upgrades on [path], or null when none is
  /// registered for it.
  static SocketHandler? socketFor(String path) =>
      socketRoutesMap[normaliseSocketPath(path)];

  /// Removes every registered route and socket. Intended for tests that
  /// register routes more than once in a single isolate.
  static void reset() {
    routesList.clear();
    socketRoutesMap.clear();
  }

  static List<Route> get routes => routesList;
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
Future<String> readBodyLimited(Stream<List<int>> stream, int maxBytes) async {
  final bytes = <int>[];
  var total = 0;
  await for (final chunk in stream) {
    total += chunk.length;
    if (total > maxBytes) {
      throw PayloadTooLargeException(
        'Request body exceeds the limit of $maxBytes bytes',
      );
    }
    bytes.addAll(chunk);
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

/// Normalises a socket [path] so a trailing slash or a missing leading one
/// resolve to the same registration.
String normaliseSocketPath(String path) => '/${splitPath(path).join('/')}';
