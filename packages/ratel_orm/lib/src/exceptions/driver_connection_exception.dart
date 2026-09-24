import 'database_exception.dart';

class DriverConnectionException extends DatabaseException {
  const DriverConnectionException(super.message, {super.cause});
}
