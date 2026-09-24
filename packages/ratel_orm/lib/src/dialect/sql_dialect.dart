import 'rewritten_sql.dart';

abstract class SqlDialect {
  RewrittenSql rewrite(String sql, Map<String, Object?>? parameters);

  bool get supportsReturning;

  String applyReturning(String sql, {required bool returning});

  String limitOffset({int? limit, int? offset});

  String quoteIdentifier(String name);

  String upsert({
    required String table,
    required List<String> columns,
    required List<String> conflictKeys,
  });

  Object? encode(Object? value);
}
