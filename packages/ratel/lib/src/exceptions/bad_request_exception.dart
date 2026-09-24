import 'http_status_exception.dart';

class BadRequestException extends HttpStatusException {
  const BadRequestException([String message = 'Bad Request'])
      : super(400, message);
}
