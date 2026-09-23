<h1 align="center">Ratel ORM</h1>

Database ORM layer for the [Ratel](https://github.com/Ratel-Dart/Ratel) framework.

`ratel` (the core framework) owns the database **contract** — `RatelDriver`,
`QueryResult`, transactions, typed exceptions and a raw-SQL facade — and stays
database-agnostic: it depends on no database package. `ratel_orm` depends on
`ratel`, implements that contract, and is the only package that pulls a real
driver in.

## What it provides

- **`RatelRepository<T>`** — `execute` for SQL with `@name` parameters and an
  opt-in `returning:`, and `find` for queries built with the query builder.
- **Row mapping** — annotate entity fields with `@Column`; the generated mapper
  is resolved by type, so a repository declares no mapper of its own.
- **Query builder** — `Query.from(...).select(...).where(...).orderBy(...)`,
  rendered per dialect.
- **Dialect layer** — identifier quoting, `LIMIT`/`OFFSET`, upserts and
  `RETURNING`, for Postgres, SQLite and MySQL.
- **Migrations** — an ordered `Migrator` with a bookkeeping table, each
  migration in its own transaction.
- **Drivers**, as sub-libraries so each stays the only place its client package
  is imported:
  - `package:ratel_orm/postgres.dart` — `PostgresDriver`, connection-pooled,
    with `PostgresDriver.fromEnv()`
  - `package:ratel_orm/sqlite.dart` — `SqliteDriver`, including `.memory()`
- **Test support** — `package:ratel_orm/testing.dart` ships a `FakeDriver`, so
  ORM logic is testable without a database.

## Setup

Entities and repositories rely on generated code, so the build step is **not
optional**. Under the Ratel CLI (`ratel dev` / `ratel build`) it is handled for
you; standalone, run `dart run build_runner build --delete-conflicting-outputs`
and call the generated `$registerRatel()` before the first query.

```dart
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/postgres.dart';

class User {
  @Column(name: 'id')
  int id = 0;

  @Column(name: 'email')
  String email = '';
}

class UserRepository extends RatelRepository<User> {
  Future<List<User>?> byEmail(String email) => execute(
        'SELECT * FROM users WHERE email = @email',
        substitutionValues: {'email': email},
      );
}

// The server opens and closes the driver as part of its lifecycle.
final server = RatelServer(database: PostgresDriver.fromEnv());
```

## Status

Early development (`0.1.0-dev`). The API may change before `1.0`.
