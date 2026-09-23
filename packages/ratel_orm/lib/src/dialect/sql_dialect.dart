import 'rewritten_sql.dart';

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
