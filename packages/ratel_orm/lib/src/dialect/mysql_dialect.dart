import 'placeholder_translator.dart';
import 'rewritten_sql.dart';
import 'standard_dialect.dart';

/// MySQL dialect: `:name` placeholders, no `RETURNING`, backtick-quoted
/// identifiers and `ON DUPLICATE KEY UPDATE` upserts.
class MysqlDialect extends StandardDialect {
  /// Creates the MySQL dialect.
  const MysqlDialect();

  @override
  RewrittenSql rewrite(String sql, Map<String, Object?>? parameters) =>
      RewrittenSql(translatePlaceholders(sql, (name) => ':$name'), parameters);

  @override
  bool get supportsReturning => false;

  @override
  String quoteIdentifier(String name) => '`$name`';

  @override
  String upsert({
    required String table,
    required List<String> columns,
    required List<String> conflictKeys,
  }) {
    final assignments = columns
        .map((c) => '${quoteIdentifier(c)} = VALUES(${quoteIdentifier(c)})')
        .join(', ');
    return 'ON DUPLICATE KEY UPDATE $assignments';
  }
}
