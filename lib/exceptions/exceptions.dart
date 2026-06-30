/// Thrown when an outbound HTTP request fails to reach the server (e.g. a
/// socket or connection error).
class HttpRequestException implements Exception {
  final String message;
  final Uri uri;
  final String? method;

  HttpRequestException(this.message, {required this.uri, this.method});

  @override
  String toString() {
    return 'HttpRequestException: $message (Method: $method, URI: $uri)';
  }
}

/// Thrown when an outbound HTTP request completes with a non-2xx [statusCode].
class HttpResponseException implements Exception {
  final String message;
  final int statusCode;
  final Uri uri;
  final String? method;

  HttpResponseException(this.message,
      {required this.statusCode, required this.uri, this.method});

  @override
  String toString() {
    return 'HttpResponseException: $message (StatusCode: $statusCode, Method: $method, URI: $uri)';
  }
}

/// Thrown when a response body cannot be decoded as JSON.
class JsonDecodingException implements Exception {
  final String message;
  final String body;

  JsonDecodingException(this.message, {required this.body});

  @override
  String toString() {
    return 'JsonDecodingException: $message (Body: $body)';
  }
}

/// Base class for server-side errors that map to a specific HTTP [statusCode].
///
/// The [message] is intended to be safe to return to clients (it must not leak
/// internal details). The server's request loop turns any thrown
/// [HttpStatusException] into a response with that status and message; all other
/// errors become a generic 500.
///
/// It is deliberately **not** named `HttpException` to avoid colliding with
/// `dart:io`'s `HttpException`.
class HttpStatusException implements Exception {
  /// The HTTP status code to respond with.
  final int statusCode;

  /// A client-safe error message.
  final String message;

  /// Extra response headers to attach (e.g. `Allow` for a 405).
  final Map<String, String> headers;

  /// Creates an exception that maps to [statusCode] with a client-safe
  /// [message] and optional response [headers].
  const HttpStatusException(
    this.statusCode,
    this.message, {
    this.headers = const {},
  });

  @override
  String toString() => 'HttpStatusException($statusCode): $message';
}

/// A 400 Bad Request — the client sent malformed or invalid input.
class BadRequestException extends HttpStatusException {
  /// Creates a 400 response with an optional [message].
  const BadRequestException([String message = 'Bad Request'])
      : super(400, message);
}

/// A 401 Unauthorized — authentication is missing or invalid.
class UnauthorizedException extends HttpStatusException {
  /// Creates a 401 response with an optional [message].
  const UnauthorizedException([String message = 'Unauthorized'])
      : super(401, message);
}

/// A 403 Forbidden — the caller is authenticated but not allowed.
class ForbiddenException extends HttpStatusException {
  /// Creates a 403 response with an optional [message].
  const ForbiddenException([String message = 'Forbidden'])
      : super(403, message);
}

/// A 404 Not Found — no route or resource matched the request.
class NotFoundException extends HttpStatusException {
  /// Creates a 404 response with an optional [message].
  const NotFoundException([String message = 'Not Found']) : super(404, message);
}

/// A 405 Method Not Allowed — the path exists but not for this HTTP method. The
/// `Allow` header lists the methods that are accepted.
class MethodNotAllowedException extends HttpStatusException {
  /// Creates a 405 response whose `Allow` header lists [allowed] methods.
  MethodNotAllowedException(Iterable<String> allowed)
      : super(
          405,
          'Method Not Allowed',
          headers: {'Allow': allowed.join(', ')},
        );
}

/// A 413 Payload Too Large — the request body exceeded the configured limit.
class PayloadTooLargeException extends HttpStatusException {
  /// Creates a 413 response with an optional [message].
  const PayloadTooLargeException([String message = 'Payload Too Large'])
      : super(413, message);
}
