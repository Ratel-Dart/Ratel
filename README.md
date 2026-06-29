<h1 align="center">Ratel</h1>

<p align="center">
    <img 
    align="center"
    height="200" 
    src="./assets/Ratel.png"/>
</p>

Ratel is a lightweight, annotation-driven backend framework for Dart. It provides
a clean way to build RESTful APIs, with built-in support for:

- **HTTP routing** via `@Get` / `@Post` / `@Put` / `@Delete` annotations
- **PostgreSQL** repositories
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
set. Built-in middleware includes `corsMiddleware` and `securityHeadersMiddleware`.

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

Configure a `RatelDatabase` and extend `RatelRepository<T>` for data access.
Map model fields to columns with `@Column`:

```dart
@Json()
class User {
  @Column(name: 'id')
  int id = 0;
  @Column(name: 'name')
  String name = '';
}

class UserRepository extends RatelRepository<User> {
  Future<List<User>?> all() => execute('SELECT id, name FROM users');
}

RatelDatabase(
  host: 'localhost',
  databaseName: 'app',
  username: 'postgres',
  password: 'postgres',
);
```

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
