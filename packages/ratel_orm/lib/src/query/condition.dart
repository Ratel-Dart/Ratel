class Condition {
  final String column;

  final String operator;

  final Object? value;

  final String connector;

  const Condition(this.column, this.operator, this.value, this.connector);
}
