class BuiltQuery {
  final String sql;

  final Map<String, Object?> parameters;

  const BuiltQuery(this.sql, this.parameters);
}
