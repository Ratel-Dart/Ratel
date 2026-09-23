/// A built SELECT statement: engine-native [sql] plus its named [parameters].
class BuiltQuery {
  /// The SQL text with canonical `@name` placeholders.
  final String sql;

  /// The parameter values keyed by placeholder name.
  final Map<String, Object?> parameters;

  /// Creates a built query.
  const BuiltQuery(this.sql, this.parameters);
}
