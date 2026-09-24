import 'http_status_exception.dart';

class MethodNotAllowedException extends HttpStatusException {
  MethodNotAllowedException(Iterable<String> allowed)
      : super(
          405,
          'Method Not Allowed',
          headers: {'Allow': allowed.join(', ')},
        );
}
