import 'http_status_exception.dart';

class ForbiddenException extends HttpStatusException {
  const ForbiddenException([String message = 'Forbidden'])
      : super(403, message);
}
