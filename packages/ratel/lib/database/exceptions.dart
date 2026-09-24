abstract class DatabaseException implements Exception {
  final String message;

  const DatabaseException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseNotConfiguredException extends DatabaseException {
  const DatabaseNotConfiguredException() : super('No RatelDriver configured.');
}

class DriverConnectionException extends DatabaseException {
  final Object? cause;

  const DriverConnectionException(super.message, {this.cause});
}

class QueryExecutionException extends DatabaseException {
  final String sql;

  final Object? cause;

  const QueryExecutionException(super.message, {required this.sql, this.cause});
}
