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
- **Row mapping** — each repository implements `fromRow`, so mapping is plain
  Dart with nothing generated.
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

A repository receives its driver in the constructor and maps each row itself.
Nothing is generated and there is no build step, so the same code runs under
`dart run`, `dart test` and `dart compile exe`.

```dart
import 'package:ratel_orm/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';

final class User {
  const User({required this.id, required this.email});

  final int id;
  final String email;
}

final class UserRepository extends RatelRepository<User> {
  UserRepository(super.driver);

  @override
  User fromRow(Map<String, Object?> row) =>
      User(id: row['id'] as int, email: row['email'] as String);

  Future<List<User>?> byEmail(String email) => execute(
        'SELECT * FROM users WHERE email = @email',
        parameters: {'email': email},
      );
}

Future<void> main() async {
  final driver = PostgresDriver.fromEnv();
  await driver.open();
  final users = await UserRepository(driver).byEmail('ada@example.com');
  print(users);
  await driver.close();
}
```

A row that `fromRow` cannot map raises a `MappingException`, and a query that
returns no rows yields `null`.

## Status

Early development (`0.1.0-dev`). The API may change before `1.0`.
