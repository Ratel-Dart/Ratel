# Migration — database layer (2.0.0-dev)

The database layer moved out of `ratel` so the core no longer depends on
`package:postgres`. The core now owns only the **driver contract** and a
**raw-SQL facade**; the ORM (`RatelRepository`, `@Column`) and the concrete
Postgres driver live in the separate [`ratel_orm`](https://github.com/Ratel-Dart/ratel_orm)
package.

## What lives where now

| Concern | Package |
|---|---|
| `RatelDriver`, `QueryResult`, `RatelSession`, `transaction`, `DatabaseException` (+ subclasses), `Db` / `server.db` | `ratel` (core) |
| `RatelRepository<T>`, `@Column`, `MappingException` | `ratel_orm` |
| `PostgresDriver`, `SslMode` | `ratel_orm` — `package:ratel_orm/postgres.dart` |

## Add the dependency

Raw SQL alone needs only a driver; the ORM needs the repository too. Both come
from `ratel_orm`:

```sh
dart pub add ratel_orm
```

## Wiring

| Before (`ratel` ≤ dev.7) | After |
|---|---|
| `RatelDatabase(host: ..., databaseName: ..., username: ..., password: ...)` | `PostgresDriver(host: ..., databaseName: ..., username: ..., password: ...)` from `package:ratel_orm/postgres.dart` |
| `RatelDatabase.fromEnv()` | `PostgresDriver.fromEnv()` |
| `RatelServer(database: ratelDatabase)` | `RatelServer(database: postgresDriver)` |
| `RatelDatabase(...)` auto-registered the driver in its constructor | `RatelServer` now registers and opens the driver in `startServer()` (no constructor side effect) |
| `@Column` / `RatelRepository` imported from `package:ratel/ratel.dart` | imported from `package:ratel_orm/ratel_orm.dart` |
| `repository.connection` (a `postgres` `Connection`) | removed — use `execute(...)` or `server.db.query(...)` |
| `catch` of `package:postgres` exceptions | catch `DatabaseException` (and subclasses) from `package:ratel` |

`RatelRepository.execute(sql, {substitutionValues})` keeps the same signature.

## Behavior change: `RETURNING *` is no longer implicit

Writes ran through `execute(...)` previously had `RETURNING *` appended
automatically on Postgres. SQL now passes through **verbatim**. To get the row
back, add the clause yourself:

```dart
// before: execute('INSERT INTO users (name) VALUES (@n)', substitutionValues: {'n': name});
await execute(
  'INSERT INTO users (name) VALUES (@n) RETURNING *',
  substitutionValues: {'n': name},
);
```

An explicit `returning:` option arrives with the dialect layer (spec 080).

## Raw SQL from the core

The core exposes the configured driver through `server.db`, without the ORM:

```dart
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/postgres.dart';

final server = RatelServer(database: PostgresDriver.fromEnv(), handlers: [...]);
await server.startServer();

final result = await server.db.query(
  'SELECT id, name FROM users WHERE id = @id',
  parameters: {'id': 1},
);
// result.rows / result.affectedRows
```
