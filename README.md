<h1 align="center">Ratel</h1>

<p align="center">
    <img 
    align="center"
    height="200" 
    src="./assets/Ratel.png"/>
</p>

Ratel is a lightweight, annotation-driven backend framework for Dart. It provides
a clean way to build RESTful APIs, with built-in support for:

- **HTTP routing** via `@Get` / `@Post` / `@Put` / `@Delete` / `@Patch` /
  `@Head` / `@Options`, with path parameters (`/users/:id`) and `@Controller`
  prefixes
- **Database-agnostic** access: a pluggable driver contract and raw SQL in the
  core (the ORM and the Postgres driver ship in
  [`ratel_orm`](https://github.com/Ratel-Dart/ratel_orm))
- **Dependency injection**
- **JWT authentication**

> **Status:** the `2.0.0-dev` line is an active hardening effort (routing,
> performance, security and tooling). APIs are changing — see the
> [CHANGELOG](CHANGELOG.md). For the stable API use `1.0.2`.

## Install

```sh
dart pub add ratel
```

## Quick start

Define a JSON model and a controller, then start the server:

```dart
import 'dart:io';

import 'package:ratel/ratel.dart';

@Json()
class Greeting {
  String message;
  Greeting({this.message = ''});
}

class HelloController extends RatelHandler {
  @Get('/hello')
  Future<Response> hello(@Param() String? name) async {
    return Response.json(
      statusCode: HttpStatus.ok,
      data: Greeting(message: 'Hello, ${name ?? 'world'}!'),
    );
  }

  @Post('/echo')
  Future<Response> echo(@Body() Greeting body) async {
    return Response.json(statusCode: HttpStatus.ok, data: body);
  }
}

Future<void> main() async {
  final server = RatelServer(port: 8080, handlers: [HelloController]);
  await server.startServer();
}
```

Run it:

```sh
dart run example/main.dart
curl "http://localhost:8080/hello?name=Ada"   # {"message":"Hello, Ada!"}
```

A complete runnable version lives in [`example/main.dart`](example/main.dart).

## Routing

Routes are declared by annotating controller methods. A class-level
`@Controller` adds a shared prefix, `:name` segments become path parameters
(bound with `@PathParam`), and `@Param` reads the query string. A request to a
known path with an unsupported method returns `405` with an `Allow` header.

```dart
@Controller('/api/v1')
class UserController extends RatelHandler {
  @Get('/users/:id')
  Future<Response> byId(@PathParam('id') int id) async =>
      Response.json(statusCode: 200, data: {'id': id});
}
```

## Authentication

Mark a controller or method `@Protected` and pass a `jwtKey` to the server.
Protected routes require an `Authorization: Bearer <token>` header.

```dart
@Protected()
class AccountController extends RatelHandler {
  @Get('/me')
  Future<Response> me() async => Response.json(statusCode: 200, data: {});

  @Public() // opt a single route out of protection
  @Get('/health')
  Future<Response> health() async => Response.json(statusCode: 200, data: {});
}

final server = RatelServer(
  port: 8080,
  handlers: [AccountController],
  jwtKey: 'your-secret',
);
```

## Middleware

Cross-cutting concerns are composable middleware. Register global middleware on
the server; the JWT auth middleware is appended automatically when `jwtKey` is
set. Built-in middleware includes `corsMiddleware`, `securityHeadersMiddleware`
and `rateLimitMiddleware`.

```dart
final server = RatelServer(
  port: 8080,
  handlers: [AccountController],
  jwtKey: 'your-secret',
  middlewares: [corsMiddleware(), securityHeadersMiddleware()],
  onStartup: () async => print('starting'),
  onShutdown: () async => print('bye'),
);
```

Role-based access uses `@Protected(roles: ['admin'])`; the caller's `roles` JWT
claim is checked, returning 403 when the role is missing.

## Database

The core is database-agnostic: it defines the `RatelDriver` contract and runs
**raw SQL** through it, with no database dependency of its own. Pass a driver to
the server and reach it via `server.db`. Concrete drivers (and the ORM) live in
the [`ratel_orm`](https://github.com/Ratel-Dart/ratel_orm) package:

```dart
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/postgres.dart'; // PostgresDriver

final server = RatelServer(
  database: PostgresDriver.fromEnv(),
  handlers: [UserController],
);
await server.startServer();

final users = await server.db.query(
  'SELECT id, name FROM users WHERE id = @id',
  parameters: {'id': 1},
);
// users.rows / users.affectedRows
```

For entity mapping, add `ratel_orm` and extend `RatelRepository<T>`, mapping
fields with `@Column` (both imported from `package:ratel_orm/ratel_orm.dart`):

```dart
import 'package:ratel_orm/ratel_orm.dart';

class User {
  @Column(name: 'id')
  int id = 0;
  @Column(name: 'name')
  String name = '';
}

class UserRepository extends RatelRepository<User> {
  Future<List<User>?> all() => execute('SELECT id, name FROM users');
}
```

Migrating from `RatelDatabase`? See
[`doc/migration-2.0-database.md`](doc/migration-2.0-database.md).

## Logging

Ratel logs through the [`logging`](https://pub.dev/packages/logging) package.
Attach a handler to receive its output:

```dart
import 'package:logging/logging.dart';

Logger.root.level = Level.INFO;
Logger.root.onRecord.listen((r) => stdout.writeln('${r.level.name}: ${r.message}'));
```

## License

[MIT](LICENSE)
