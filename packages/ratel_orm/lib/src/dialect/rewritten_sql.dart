/// A SQL statement rewritten for a specific engine, together with the
/// parameters in the shape that engine expects.
class RewrittenSql {
  /// The engine-native SQL.
  final String sql;

  /// The parameters, named (`Map`) or positional (`List`) per the dialect.
  final Object? parameters;

  /// Creates a rewritten statement.
  const RewrittenSql(this.sql, this.parameters);
}
