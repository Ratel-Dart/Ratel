import 'package:ratel/ratel.dart' show DatabaseException;

class MappingException extends DatabaseException {
  const MappingException(super.message);
}
