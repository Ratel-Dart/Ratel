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

/// Engine-specific SQL quirks: placeholder style, RETURNING support,
/// pagination, identifier quoting, upsert syntax and value encoding.
///
/// The ORM emits canonical `@name` placeholders; a dialect translates them and
/// the surrounding SQL to the engine's native form.
abstract class SqlDialect {
  /// Rewrites canonical `@name` [sql] and its [parameters] to the engine-native
  /// form. Pure: no I/O.
  RewrittenSql rewrite(String sql, Map<String, Object?>? parameters);

  /// Whether the engine supports a `RETURNING` clause on writes.
  bool get supportsReturning;

  /// Appends a returning clause when [returning] is requested and supported;
  /// otherwise returns [sql] unchanged.
  String applyReturning(String sql, {required bool returning});

  /// A `LIMIT`/`OFFSET` fragment for the engine.
  String limitOffset({int? limit, int? offset});

  /// Quotes an identifier (e.g. `"col"` or `` `col` ``).
  String quoteIdentifier(String name);

  /// The upsert conflict clause for [table] writing [columns], keyed on
  /// [conflictKeys].
  String upsert({
    required String table,
    required List<String> columns,
    required List<String> conflictKeys,
  });

  /// Encodes a Dart [value] into the form the driver binds.
  Object? encode(Object? value);
}

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

/// PostgreSQL dialect. `@name` is native (via `Sql.named`), so [rewrite] is the
/// identity.
class PostgresDialect extends StandardDialect {
  /// Creates the Postgres dialect.
  const PostgresDialect();
}

/// SQLite dialect. `@name` is a native placeholder; `RETURNING` requires
/// SQLite 3.35+.
class SqliteDialect extends StandardDialect {
  /// Creates the SQLite dialect.
  const SqliteDialect();
}

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

/// Rewrites `@name` placeholders in [sql] using [render], skipping string
/// literals, comments and `::` casts so operators like `@>`/`@@` and `@` inside
/// strings are left intact.
String translatePlaceholders(String sql, String Function(String name) render) {
  final out = StringBuffer();
  var i = 0;
  while (i < sql.length) {
    final char = sql[i];

    if (char == "'" || char == '"') {
      i = _copyStringLiteral(sql, i, out);
      continue;
    }
    if (char == '-' && _peek(sql, i + 1) == '-') {
      i = _copyLineComment(sql, i, out);
      continue;
    }
    if (char == '/' && _peek(sql, i + 1) == '*') {
      i = _copyBlockComment(sql, i, out);
      continue;
    }
    if (char == ':' && _peek(sql, i + 1) == ':') {
      out.write('::');
      i += 2;
      continue;
    }
    if (char == '@') {
      var j = i + 1;
      while (j < sql.length && _isNameChar(sql[j])) {
        j++;
      }
      if (j > i + 1) {
        out.write(render(sql.substring(i + 1, j)));
        i = j;
        continue;
      }
    }
    out.write(char);
    i++;
  }
  return out.toString();
}

int _copyStringLiteral(String sql, int start, StringBuffer out) {
  final quote = sql[start];
  out.write(quote);
  var i = start + 1;
  while (i < sql.length) {
    final char = sql[i];
    out.write(char);
    if (char == quote) {
      if (_peek(sql, i + 1) == quote) {
        out.write(quote);
        i += 2;
        continue;
      }
      return i + 1;
    }
    i++;
  }
  return i;
}

int _copyLineComment(String sql, int start, StringBuffer out) {
  var i = start;
  while (i < sql.length && sql[i] != '\n') {
    out.write(sql[i]);
    i++;
  }
  return i;
}

int _copyBlockComment(String sql, int start, StringBuffer out) {
  out.write('/*');
  var i = start + 2;
  while (i < sql.length && !(sql[i] == '*' && _peek(sql, i + 1) == '/')) {
    out.write(sql[i]);
    i++;
  }
  if (i < sql.length) {
    out.write('*/');
    return i + 2;
  }
  return i;
}

String? _peek(String sql, int index) => index < sql.length ? sql[index] : null;

bool _isNameChar(String char) {
  final code = char.codeUnitAt(0);
  final isDigit = code >= 48 && code <= 57;
  final isUpper = code >= 65 && code <= 90;
  final isLower = code >= 97 && code <= 122;
  return isDigit || isUpper || isLower || char == '_';
}
