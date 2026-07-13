import 'query_result.dart';

/// A connection scoped to an open transaction.
///
/// Passed to the callback of `RatelDriver.transaction`; every [query] runs on
/// the same connection so the statements commit or roll back atomically.
abstract class RatelSession {
  /// Runs [sql] with optional named [parameters] on the transaction's
  /// connection.
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters});
}
