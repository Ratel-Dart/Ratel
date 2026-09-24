import 'http_status_exception.dart';

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
