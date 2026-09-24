import 'database_exception.dart';

class MappingException extends DatabaseException {
  const MappingException(super.message, {super.cause});
}
