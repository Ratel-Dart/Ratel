/// The result of executing a SQL statement through a `RatelDriver`.
///
/// Carries the returned [rows] plus execution metadata. Statements that return
/// no rows yield an empty [rows] list, never an error.
class QueryResult {
  /// Rows returned by the statement, each as a column-name to value map.
  ///
  /// Keys are the column names exactly as the database returns them.
  final List<Map<String, Object?>> rows;

  /// Number of rows affected by an INSERT/UPDATE/DELETE, or 0 when the
  /// statement does not report one.
  final int affectedRows;

  /// The auto-generated key of the last inserted row when the engine exposes
  /// one, or null otherwise (Postgres, for instance, uses `RETURNING`).
  final int? lastInsertId;

  /// Creates a query result.
  const QueryResult({
    this.rows = const [],
    this.affectedRows = 0,
    this.lastInsertId,
  });

  /// Whether the statement returned no rows.
  bool get isEmpty => rows.isEmpty;
}
