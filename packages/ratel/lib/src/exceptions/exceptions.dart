class HttpStatusException implements Exception {
  final int statusCode;

  final String message;

  final Map<String, String> headers;

  const HttpStatusException(
    this.statusCode,
    this.message, {
    this.headers = const {},
  });

  @override
  String toString() => 'HttpStatusException($statusCode): $message';
}

class BadRequestException extends HttpStatusException {
  const BadRequestException([String message = 'Bad Request'])
      : super(400, message);
}

class UnauthorizedException extends HttpStatusException {
  const UnauthorizedException([String message = 'Unauthorized'])
      : super(401, message);
}

class ForbiddenException extends HttpStatusException {
  const ForbiddenException([String message = 'Forbidden'])
      : super(403, message);
}

class NotFoundException extends HttpStatusException {
  const NotFoundException([String message = 'Not Found']) : super(404, message);
}

class MethodNotAllowedException extends HttpStatusException {
  MethodNotAllowedException(Iterable<String> allowed)
      : super(
          405,
          'Method Not Allowed',
          headers: {'Allow': allowed.join(', ')},
        );
}

class PayloadTooLargeException extends HttpStatusException {
  const PayloadTooLargeException([
    String message = 'Payload Too Large',
    Map<String, String> headers = const {},
  ]) : super(413, message, headers: headers);
}

class TooManyRequestsException extends HttpStatusException {
  TooManyRequestsException({int? retryAfterSeconds})
      : super(
          429,
          'Too Many Requests',
          headers: retryAfterSeconds == null
              ? const {}
              : {'Retry-After': '$retryAfterSeconds'},
        );
}

class RatelSerializationException implements Exception {
  final Type type;

  const RatelSerializationException(this.type);

  @override
  String toString() =>
      'RatelSerializationException: no JSON encoder for $type. Annotate $type '
      'with @Json(), or give it a toJson() method.';
}
