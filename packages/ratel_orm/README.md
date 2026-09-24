<h1 align="center">Ratel ORM</h1>

A standalone SQL toolkit for Dart: a driver contract with Postgres and SQLite
drivers, repositories with explicit row mapping, a query builder and
migrations.

It depends on no web framework. It works in a CLI, a worker or a test, and it
works next to [Ratel](https://github.com/Ratel-Dart/Ratel) the way Prisma works
next to NestJS: the two fit together, and neither needs the other.

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

## Using it with Ratel

Ratel has no database layer. The server's startup and shutdown hooks open and
close the driver, and `Bindings` hands repositories to controllers:

```dart
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';

class AppBindings extends Bindings {
  AppBindings(this.driver);

  final RatelDriver driver;

  @override
  void dependencies() {
    Injector().put<UserRepository>(() => UserRepository(driver));
  }
}

Future<void> main() async {
  final driver = PostgresDriver.fromEnv();
  final server = RatelServer(
    port: 8080,
    bindings: AppBindings(driver),
    onStartup: driver.open,
    onShutdown: driver.close,
  );
  await server.startServer();
}
```

## The driver contract

`RatelDriver` is a base class that drivers extend, so members can be added
without breaking them. Every driver follows these rules, and the conformance
suite in this repository checks them:

- Parameters use named placeholders (`@name`) matching the keys of the
  `parameters` map. With no parameters, the SQL runs verbatim.
- Accepted parameter values are `null`, `bool`, `int`, `double`, `String`,
  `DateTime` and `List<int>` (bytes).
- Native engine errors surface as a `DatabaseException`.
- `open` is idempotent. `close` releases every resource.
- `transaction` runs its action on one connection, commits when the action
  completes and rolls back when it throws.
- `dialect` tells the query builder how to quote identifiers and render
  `LIMIT`, `OFFSET` and `RETURNING`.

## Testing

`package:ratel_orm/testing.dart` ships `FakeDriver`, an in-memory driver:
queue results with `enqueue` or `enqueueRows`, inspect the last call through
`lastSql` and `lastParameters`, and force a failure with `errorToThrow`. It
does not import `package:test`, so it is safe to use outside tests.

## Status

Early development (`0.1.0-dev`). The API may change before `1.0`.
