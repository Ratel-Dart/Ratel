import 'sql_dialect.dart';

class StandardDialect implements SqlDialect {
  const StandardDialect();

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
}
