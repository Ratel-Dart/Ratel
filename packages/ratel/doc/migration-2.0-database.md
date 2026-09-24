# Migration — database layer (2.0.0-dev)

Ratel no longer has a database layer. Everything about databases lives in
[`ratel_orm`](https://pub.dev/packages/ratel_orm), which does not depend on
`ratel`. The two work together through dependency injection and the server's
startup and shutdown hooks, and each is usable without the other.

> **This is half of the release.** The same version also replaced `dart:mirrors`
> with code generation, which changes how controllers and `@Json` models are
> written and how an application is run. See the `2.0.0-dev` entries in
> [`CHANGELOG.md`](../CHANGELOG.md) for that half.

## What lives where now

| Concern | Import |
|---|---|
| `RatelDriver`, `RatelSession`, `QueryResult`, `DatabaseException` and its subclasses, `RatelRepository<T>`, `MappingException`, `Query`, `Migrator` | `package:ratel_orm/ratel_orm.dart` |
| `PostgresDriver`, `SslMode` | `package:ratel_orm/postgres.dart` |
| `SqliteDriver` | `package:ratel_orm/sqlite.dart` |
| `FakeDriver` | `package:ratel_orm/testing.dart` |

## Add the dependency

```sh
dart pub add ratel_orm
```

## Wiring

| Before (`ratel` 2.0.0-dev.6 and earlier) | After |
|---|---|
| `RatelDatabase(host: ..., databaseName: ..., username: ..., password: ...)` | `PostgresDriver(host: ..., databaseName: ..., username: ..., password: ...)` |
| `RatelDatabase.fromEnv()` | `PostgresDriver.fromEnv()` |
| `RatelServer(database: ratelDatabase)` | `RatelServer(onStartup: driver.open, onShutdown: driver.close, bindings: ...)` |
| `server.db.query(...)` | `driver.query(...)` on the driver you created |
| `@Column` fields mapped by reflection | a `fromRow` override on the repository |
| a repository that found the driver on its own | a repository that takes the driver in its constructor: `UserRepository(driver)` |
| `repository.connection` (a `postgres` `Connection`) | removed; use `execute(...)` or `driver.query(...)` |
| `catch` of `package:postgres` exceptions | `catch` of `DatabaseException` and its subclasses |

`execute(sql, {substitutionValues})` became `execute(sql, {parameters})`.

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

## Behavior change: `RETURNING *` is no longer implicit

Writes run through `execute(...)` used to have `RETURNING *` appended
automatically on Postgres. SQL now passes through **verbatim**. To get the row
back, add the clause yourself:

```dart
await execute(
  'INSERT INTO users (name) VALUES (@n) RETURNING *',
  parameters: {'n': name},
);
```

Or let the dialect add it, which keeps the SQL portable:

```dart
await execute(
  'INSERT INTO users (name) VALUES (@n)',
  parameters: {'n': name},
  returning: true,
);
```
