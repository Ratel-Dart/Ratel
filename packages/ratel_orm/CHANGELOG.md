## 0.1.0-dev.1 (unreleased)

- Row mappers are generated and resolved from a registry instead of
  `dart:mirrors`, so the ORM no longer blocks `dart compile exe`.
  `RatelRepository`'s mapper argument became optional — a repository that
  relies on `@Column` now needs no constructor at all.
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
- Initial package scaffold: `RatelRepository<T>`, `@Column` and
  `MappingException` extracted from the `ratel` core.
