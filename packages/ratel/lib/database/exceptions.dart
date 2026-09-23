/// Base class for every database error surfaced by the Ratel data layer.
///
/// Drivers convert native engine exceptions into subclasses of this type so
/// callers never see driver-specific exceptions. Consumers (the raw-SQL facade
/// and the ORM repository) rethrow these unchanged.
abstract class DatabaseException implements Exception {
  /// A human-readable description of the failure.
  final String message;

  /// Creates a database exception with the given [message].
  const DatabaseException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the data layer is used before a driver is configured.
class DatabaseNotConfiguredException extends DatabaseException {
  /// Creates the exception.
  const DatabaseNotConfiguredException() : super('No RatelDriver configured.');
}

/// Thrown when a driver fails to connect or initialize.
class DriverConnectionException extends DatabaseException {
  /// The underlying native error, when available.
  final Object? cause;

  /// Creates the exception.
  const DriverConnectionException(super.message, {this.cause});
}

/// Thrown when a statement fails to execute.
///
/// Carries the offending [sql] and the original [cause].
class QueryExecutionException extends DatabaseException {
  /// The SQL statement that failed.
  final String sql;

  /// The underlying native error, when available.
  final Object? cause;

  /// Creates the exception.
  const QueryExecutionException(super.message, {required this.sql, this.cause});
}
