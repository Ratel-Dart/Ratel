import '../dialect.dart';

/// Opt-in helper that appends `RETURNING *` to a write statement.
///
/// Not applied automatically by `PostgresDriver.query`, which runs SQL
/// verbatim. Delegates to [PostgresDialect.applyReturning]; prefer the
/// `returning:` option on `RatelRepository.execute`.
String applyReturningClause(String sql) =>
    const PostgresDialect().applyReturning(sql, returning: true);
