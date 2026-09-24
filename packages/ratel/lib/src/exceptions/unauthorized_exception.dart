import 'http_status_exception.dart';

class UnauthorizedException extends HttpStatusException {
  const UnauthorizedException([String message = 'Unauthorized'])
      : super(401, message);
}
