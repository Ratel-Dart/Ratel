import 'database_exception.dart';

class QueryExecutionException extends DatabaseException {
  const QueryExecutionException(
    super.message, {
    required this.sql,
    super.cause,
  });

  final String sql;
}
