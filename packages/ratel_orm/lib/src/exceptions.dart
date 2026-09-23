import 'package:ratel/ratel.dart' show DatabaseException;

/// Thrown when a query result row cannot be mapped onto its entity.
///
/// The [message] names the entity, field and column that failed.
class MappingException extends DatabaseException {
  /// Creates a mapping exception with the given [message].
  const MappingException(super.message);
}
