## 0.1.0-dev.1 (unreleased)

- The unused MySQL path is gone: `MysqlDialect`, the placeholder translator,
  `RewrittenSql` and `SqlDialect.rewrite`, `upsert` and `encode`, none of
  which any driver called. `applyReturningClause` is gone as well; it
  duplicated `PostgresDialect.applyReturning`. `SqlDialect` is now an
  interface with the four members the query builder and repository use.
- `ratel_orm` no longer depends on `ratel`. The driver contract moved here from
  the framework: `RatelDriver`, `RatelSession`, `QueryResult`,
  `DatabaseException`, `QueryExecutionException` and
  `DriverConnectionException` are exported from
  `package:ratel_orm/ratel_orm.dart`. `DatabaseNotConfiguredException` is gone,
  together with the framework's `Db` it belonged to.
- `OrmDriver` merged into `RatelDriver`, which now declares `SqlDialect get
  dialect`. `FakeDriver` uses the standard dialect, so `returning: true` on a
  repository backed by it now appends `RETURNING *` as it does on a real driver.
- `cause` moved onto `DatabaseException`, and `MappingException` now keeps
  the error that broke the mapping.
- Row mapping is explicit. A repository implements `T fromRow(Map<String,
  Object?> row)` and takes its driver in the constructor:
  `UserRepository(driver)`. Nothing is generated or reflected, so the ORM runs
  in any Dart program, JIT or AOT, with no build step. `@Column`,
  `RatelRowMappers` and `RatelRepository.configure` are gone, and
  `execute`'s `substitutionValues:` is now `parameters:`.
- Fluent `SELECT` query builder, reached through `RatelRepository.find`.
- Schema migration engine: ordered application against a bookkeeping table,
  each migration in its own transaction.
- SQL dialect layer (`SqlDialect`) covering identifier quoting,
  `LIMIT`/`OFFSET`, and an opt-in `returning:` on `execute`. SQL is
  otherwise passed through verbatim — the automatic `RETURNING *` the old
  repository appended is gone.
- SQLite driver at `package:ratel_orm/sqlite.dart`.
- Postgres driver at `package:ratel_orm/postgres.dart`, over a connection pool,
  with `PostgresDriver.fromEnv()`.
- `FakeDriver` and a driver conformance suite for testing without a database.
- Initial package scaffold: `RatelRepository<T>` and `MappingException`
  extracted from the `ratel` core.
