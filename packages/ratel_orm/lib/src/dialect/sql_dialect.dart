abstract interface class SqlDialect {
  bool get supportsReturning;

  String applyReturning(String sql, {required bool returning});

  String limitOffset({int? limit, int? offset});

  String quoteIdentifier(String name);
}
