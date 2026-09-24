# Migration — database layer (2.0.0-dev)

The database layer moved out of `ratel` so the core no longer depends on
`package:postgres`. The core now owns only the **driver contract** and a
**raw-SQL facade**; the ORM (`RatelRepository`) and the concrete
Postgres driver live in the separate [`ratel_orm`](https://github.com/Ratel-Dart/ratel_orm)
package.

> **This is half of the release.** The same version also replaced `dart:mirrors`
> with code generation, which changes how controllers and `@Json` models are
> written and how an application is run — `RatelServer(handlers:)` is gone,
> annotated classes must be public, and `ratel dev` / `ratel build` replace
> `dart run`. Following this guide alone will not get you compiling; see the
> `2.0.0-dev` entry in [`CHANGELOG.md`](../CHANGELOG.md) for that half.

## What lives where now

| Concern | Package |
|---|---|
| `RatelDriver`, `QueryResult`, `RatelSession`, `transaction`, `DatabaseException` (+ subclasses), `Db` / `server.db` | `ratel` (core) |
| `RatelRepository<T>`, `MappingException` | `ratel_orm` |
| `PostgresDriver`, `SslMode` | `ratel_orm` — `package:ratel_orm/postgres.dart` |

## Add the dependency

Raw SQL alone needs only a driver; the ORM needs the repository too. Both come
from `ratel_orm`:

```sh
dart pub add ratel_orm
```

## Wiring

| Before (`ratel` 2.0.0-dev.6 and earlier) | After |
|---|---|
| `RatelDatabase(host: ..., databaseName: ..., username: ..., password: ...)` | `PostgresDriver(host: ..., databaseName: ..., username: ..., password: ...)` from `package:ratel_orm/postgres.dart` |
| `RatelDatabase.fromEnv()` | `PostgresDriver.fromEnv()` |
| `RatelServer(database: ratelDatabase)` | `RatelServer(database: postgresDriver)` |
| `RatelDatabase(...)` auto-registered the driver in its constructor | `RatelServer` now registers and opens the driver in `startServer()` (no constructor side effect) |
| `@Column` fields mapped by reflection | a `fromRow` override on the repository, which takes its driver in the constructor |
| `RatelRepository` imported from `package:ratel/ratel.dart` | imported from `package:ratel_orm/ratel_orm.dart` |
| `repository.connection` (a `postgres` `Connection`) | removed — use `execute(...)` or `server.db.query(...)` |
| `catch` of `package:postgres` exceptions | catch `DatabaseException` (and subclasses) from `package:ratel` |

`RatelRepository.execute(sql, {substitutionValues})` became
`execute(sql, {parameters})`.

## Behavior change: `RETURNING *` is no longer implicit

Writes ran through `execute(...)` previously had `RETURNING *` appended
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

## Raw SQL from the core

The core exposes the configured driver through `server.db`, without the ORM:

```dart
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/postgres.dart';

final server = RatelServer(database: PostgresDriver.fromEnv());
await server.startServer();

final result = await server.db.query(
  'SELECT id, name FROM users WHERE id = @id',
  parameters: {'id': 1},
);
// result.rows / result.affectedRows
```
