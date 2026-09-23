import 'standard_dialect.dart';

/// PostgreSQL dialect. `@name` is native (via `Sql.named`), so `rewrite` is the
/// identity.
class PostgresDialect extends StandardDialect {
  /// Creates the Postgres dialect.
  const PostgresDialect();
}
