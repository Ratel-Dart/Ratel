/// One `WHERE` term: `column operator value`, joined to the previous term by
/// [connector]. Internal to the query builder; never exported.
class Condition {
  /// The column being compared.
  final String column;

  /// The comparison operator, rendered verbatim.
  final String operator;

  /// The value, always bound as a parameter.
  final Object? value;

  /// `AND` or `OR`, ignored for the first term.
  final String connector;

  /// Creates a condition.
  const Condition(this.column, this.operator, this.value, this.connector);
}
