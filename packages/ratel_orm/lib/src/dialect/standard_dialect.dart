import 'rewritten_sql.dart';
import 'sql_dialect.dart';

/// A PostgreSQL-like default dialect: `@name` placeholders, `RETURNING`,
/// double-quoted identifiers and `ON CONFLICT` upserts.
class StandardDialect implements SqlDialect {
  /// Creates the default dialect.
  const StandardDialect();

  @override
  RewrittenSql rewrite(String sql, Map<String, Object?>? parameters) =>
      RewrittenSql(sql, parameters);

  @override
  bool get supportsReturning => true;

  @override
  String applyReturning(String sql, {required bool returning}) {
    if (!returning || !supportsReturning) return sql;
    var statement = sql.trim();
    if (statement.endsWith(';')) {
      statement = statement.substring(0, statement.length - 1);
    }
    final upper = statement.toUpperCase();
    final isWrite = upper.startsWith('INSERT') ||
        upper.startsWith('UPDATE') ||
        upper.startsWith('DELETE');
    if (isWrite && !upper.contains('RETURNING')) {
      statement += ' RETURNING *';
    }
    return statement;
  }

  @override
  String limitOffset({int? limit, int? offset}) {
    final parts = <String>[];
    if (limit != null) parts.add('LIMIT $limit');
    if (offset != null) parts.add('OFFSET $offset');
    return parts.join(' ');
  }

  @override
  String quoteIdentifier(String name) => '"$name"';

  @override
  String upsert({
    required String table,
    required List<String> columns,
    required List<String> conflictKeys,
  }) {
    final keys = conflictKeys.map(quoteIdentifier).join(', ');
    final assignments = columns
        .map((c) => '${quoteIdentifier(c)} = EXCLUDED.${quoteIdentifier(c)}')
        .join(', ');
    return 'ON CONFLICT ($keys) DO UPDATE SET $assignments';
  }

  @override
  Object? encode(Object? value) => value;
}
