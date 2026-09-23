import 'standard_dialect.dart';

/// SQLite dialect. `@name` is a native placeholder; `RETURNING` requires
/// SQLite 3.35+.
class SqliteDialect extends StandardDialect {
  /// Creates the SQLite dialect.
  const SqliteDialect();
}
