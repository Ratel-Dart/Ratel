class QueryResult {
  final List<Map<String, Object?>> rows;

  final int affectedRows;

  final int? lastInsertId;

  const QueryResult({
    this.rows = const [],
    this.affectedRows = 0,
    this.lastInsertId,
  });

  bool get isEmpty => rows.isEmpty;
}
