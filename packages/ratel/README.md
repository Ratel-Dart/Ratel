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
- **Native binaries**: `ratel build` compiles the whole app ahead of time

> **Status:** the `2.0.0-dev` line is an active hardening effort (routing,
> performance, security and tooling). APIs are changing — see the
> [CHANGELOG](CHANGELOG.md). For the stable API use `1.0.3`.

## Install

```sh
dart pub global activate ratel
```

## Quick start

```sh
ratel create my_api
cd my_api
ratel dev
```

Define a JSON model and a controller — that is all the code there is:

```dart
import 'package:ratel/ratel.dart';

@Json()
class Greeting {
  String message;
  Greeting({this.message = ''});
}

class HelloController extends RatelHandler {
  @Get('/hello')
  Future<Response> hello(@Param() String? name) async {
    return Response.json(data: Greeting(message: 'Hello, ${name ?? 'world'}!'));
  }

  @Post('/echo')
  Future<Response> echo(@Body() Greeting body) async {
    return Response.json(data: body);
  }
}
```

```dart
// bin/server.dart
Future<void> main() async {
  final server = RatelServer(port: 8080);
  await server.startServer();
}
```

```sh
curl "http://localhost:8080/hello?name=Ada"   # {"message":"Hello, Ada!"}
```

`ratel dev` reloads on every change. A complete runnable version lives in
[`example/main.dart`](example/main.dart).

## Commands

| Command | What it does |
| --- | --- |
| `ratel create <name>` | Scaffold a new application. |
| `ratel dev` | Run the app, rebuilding and restarting on change. |
| `ratel build` | Compile a native binary to `build/server`. |

Ratel reads your annotations at build time rather than through reflection, which
is what lets an app compile to a native binary. The CLI runs that step for you —
`ratel dev` and `ratel build` regenerate before they run, so there is no
generation command to remember and no generated code to write by hand. The
`.ratel.dart` files it produces are build output; leave them gitignored.

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
      Response.json(data: {'id': id});
}
```

A parameter typed `RequestContext` receives the context for the request — the
raw `HttpRequest`, the matched route, the path parameters, the JWT claims and
the middleware state bag — without an annotation.

```dart
@Get('/me')
Future<Response> me(RequestContext ctx) async =>
    Response.json(data: {'sub': ctx.claims?['sub']});
```

A `HEAD` request with no `@Head` route of its own is answered from the `GET`
route for the same path, with its status and headers but no body.

A `multipart/form-data` upload is parsed into a `MultipartData` parameter, which
carries the text `fields` and the uploaded `files`. The server's
`maxRequestBodyBytes` limit applies across every part together.

```dart
@Post('/avatar')
Future<Response> avatar(MultipartData form) async {
  final file = form.file('avatar');
  await File('uploads/${file!.filename}').writeAsBytes(file.bytes);
  return Response.json(data: {'saved': file.filename});
}
```

## Authentication

Mark a controller or method `@Protected` and pass a `jwtKey` to the server.
Protected routes require an `Authorization: Bearer <token>` header.

```dart
@Protected()
class AccountController extends RatelHandler {
  @Get('/me')
  Future<Response> me() async => Response.json(data: {});

  @Public() // opt a single route out of protection
  @Get('/health')
  Future<Response> health() async => Response.json(data: {});
}

final server = RatelServer(port: 8080, jwtKey: 'your-secret');
```

## Middleware

Cross-cutting concerns are composable middleware. Register global middleware on
the server; the JWT auth middleware is appended automatically when `jwtKey` is
set. Built-in middleware includes `corsMiddleware`, `securityHeadersMiddleware`
and `rateLimitMiddleware`.

```dart
final server = RatelServer(
  port: 8080,
  jwtKey: 'your-secret',
  middlewares: [corsMiddleware(), securityHeadersMiddleware()],
  onStartup: () async => print('starting'),
  onShutdown: () async => print('bye'),
);
```

Role-based access uses `@Protected(roles: ['admin'])`; the caller's `roles` JWT
claim is checked, returning 403 when the role is missing.

## Scaling across cores

A Dart isolate uses one core. `runCluster` runs the application's startup on one
isolate per core, and `shared: true` lets every one of them bind the same port,
with the OS spreading connections across them.

```dart
void main() => runCluster(serve);

void serve(List<String> args) {
  $registerRatel();
  RatelServer(port: 8080, shared: true).startServer();
}
```

Isolates share no memory, so the entry point does the whole startup — routes,
bindings and the server — on each one. It must be a top-level or static
function.

## Database

The core is database-agnostic: it defines the `RatelDriver` contract and runs
**raw SQL** through it, with no database dependency of its own. Pass a driver to
the server and reach it via `server.db`. Concrete drivers (and the ORM) live in
the [`ratel_orm`](https://github.com/Ratel-Dart/ratel_orm) package:

```dart
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/postgres.dart'; // PostgresDriver

final server = RatelServer(database: PostgresDriver.fromEnv());
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
