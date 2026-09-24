## 0.1.0-dev.1 (unreleased)

- Row mapping is explicit. A repository implements `T fromRow(Map<String,
  Object?> row)` and takes its driver in the constructor:
  `UserRepository(driver)`. Nothing is generated or reflected, so the ORM runs
  in any Dart program, JIT or AOT, with no build step. `@Column`,
  `RatelRowMappers` and `RatelRepository.configure` are gone, and
  `execute`'s `substitutionValues:` is now `parameters:`.
- Fluent `SELECT` query builder, reached through `RatelRepository.find`.
- Schema migration engine: ordered application against a bookkeeping table,
  each migration in its own transaction.
- SQL dialect layer (`SqlDialect`, `OrmDriver`) covering identifier quoting,
  `LIMIT`/`OFFSET`, upserts, and an opt-in `returning:` on `execute`. SQL is
  otherwise passed through verbatim — the automatic `RETURNING *` the old
  repository appended is gone.
- SQLite driver at `package:ratel_orm/sqlite.dart`.
- Postgres driver at `package:ratel_orm/postgres.dart`, over a connection pool,
  with `PostgresDriver.fromEnv()`.
- `FakeDriver` and a driver conformance suite for testing without a database.
- Initial package scaffold: `RatelRepository<T>` and `MappingException`
  extracted from the `ratel` core.
