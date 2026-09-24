import 'http_status_exception.dart';

class NotFoundException extends HttpStatusException {
  const NotFoundException([String message = 'Not Found']) : super(404, message);
}
