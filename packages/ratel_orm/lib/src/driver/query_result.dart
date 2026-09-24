final class QueryResult {
  const QueryResult({
    this.rows = const [],
    this.affectedRows = 0,
    this.lastInsertId,
  });

  final List<Map<String, Object?>> rows;
  final int affectedRows;
  final int? lastInsertId;

  bool get isEmpty => rows.isEmpty;
}
