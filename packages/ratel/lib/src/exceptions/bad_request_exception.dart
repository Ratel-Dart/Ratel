import 'http_status_exception.dart';

class BadRequestException extends HttpStatusException {
  const BadRequestException([
    String message = 'Bad Request',
    Map<String, String> headers = const {},
  ]) : super(400, message, headers: headers);
}
