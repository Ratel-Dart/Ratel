import 'http_status_exception.dart';

class PayloadTooLargeException extends HttpStatusException {
  const PayloadTooLargeException([
    String message = 'Payload Too Large',
    Map<String, String> headers = const {},
  ]) : super(413, message, headers: headers);
}
