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
- **No database lock-in**: the framework has no database layer, so any client
  plugs in through dependency injection and the startup and shutdown hooks.
  The separate [`ratel_orm`](https://pub.dev/packages/ratel_orm) package is
  one option.
- **Dependency injection**
- **JWT authentication**
- **Native binaries**: `ratel build` compiles the whole app ahead of time

> **Status:** the `2.0.0-dev` line is an active hardening effort (routing,
> performance, security and tooling). APIs are changing — see the
> [CHANGELOG](CHANGELOG.md). For the stable API use `1.0.3`.

## Install

The `ratel` command comes from the [`ratel_cli`](https://pub.dev/packages/ratel_cli) package:

```sh
dart pub global activate ratel_cli
```

## Quick start

```sh
ratel create my_api
cd my_api
ratel dev
```

A JSON model and a controller, each in its own file, are all the code there is.
`lib/models/greeting.dart`:

```dart
import 'package:ratel/ratel.dart';

@Json()
class Greeting {
  Greeting({this.message = ''});

  String message;
}
```

`lib/controllers/hello_controller.dart`:

```dart
import 'package:my_api/models/greeting.dart';
import 'package:ratel/ratel.dart';

@Controller()
class HelloController {
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

The entrypoint in `bin/server.dart` only starts the server:

```dart
Future<void> main() async {
  final server = RatelServer(port: 8080);
  await server.startServer();
}
```

```sh
curl "http://localhost:8080/hello?name=Ada"   # {"message":"Hello, Ada!"}
```

`ratel dev` restarts the server on every change. A complete runnable version
lives in [`example/`](example): `main.dart` starts the server, and the
controller and the model sit in their own folders, found without any import.

## Commands

| Command | What it does |
| --- | --- |
| `ratel create <name>` | Scaffold a new application. |
| `ratel dev [entrypoint] [-- args]` | Run the app and restart it on every change. |
| `ratel build [entrypoint]` | Compile a native binary into `build/`. |
| `ratel test [paths] [-- args]` | Run the tests with the routes wired, so a test can start a `RatelServer` and call it. |

Ratel finds every `@Controller` class in `lib/` and next to the entrypoint,
including files nothing imports, and wires their routes before `main` runs. It
reads the annotations with the Dart analyzer instead of reflection, which is
what lets an app compile to a native binary, and it keeps the wiring under
`.dart_tool/ratel/`: nothing is generated into your project, there is no
build_runner, and there is no step to run by hand. Start the app through
`ratel`; a plain `dart run bin/server.dart` skips discovery.

Started any other way, `RatelServer` stops with an error that points at
`ratel dev` instead of serving nothing. A test or tool that wants routes
without the CLI builds them by hand and passes them in:

```dart
final server = RatelServer(
  port: 0,
  registry: RatelRegistry()
    ..register(Route(
      method: 'GET',
      path: '/ping',
      handler: (ctx) async => Response.json(data: {'ok': true}),
    )),
);
```

When a file changes, `ratel dev` re-analyzes only what changed and restarts
the server. If the change does not compile, it prints the errors as
`file:line` and keeps the previous server running.

## Routing

Routes are declared by annotating controller methods. A class-level
`@Controller` adds a shared prefix, `:name` segments become path parameters
(bound with `@PathParam`), and `@Param` reads the query string. A request to a
known path with an unsupported method returns `405` with an `Allow` header.

```dart
@Controller('/api/v1')
class UserController {
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

## Responses

A handler returns a `Response` (or any value, which is wrapped as JSON).
`Response.json`, `Response.text`, `Response.html` and `Response.bytes` pick the
representation, `Response.redirect` sends a `Location`, and `withCookie`
attaches a `Set-Cookie` header built with the flags the response needs.

```dart
@Post('/sign-in')
Future<Response> signIn() async => Response.json(data: {'ok': true}).withCookie(
      Cookie('session', token)
        ..httpOnly = true
        ..secure = true
        ..sameSite = SameSite.strict,
    );
```

A handler streams Server-Sent Events by returning `Response.sse`. Each value of
the stream is sent as one `data:` frame and the connection stays open until the
stream closes.

```dart
@Get('/prices')
Future<Response> prices() async => Response.sse(priceTicks.map(jsonEncode));
```

## Errors

Throwing an `HttpStatusException` — `BadRequestException`, `NotFoundException`,
`ForbiddenException` and the rest — answers with that status and message. Any
other error is logged with a correlation id and answered with a generic `500`,
so internal detail never reaches the client.

`onError` maps those unexpected errors onto a response of your own, which is
where a domain exception becomes an HTTP status. The error is still logged
first, and a hook that throws falls back to the generic `500`.

```dart
final server = RatelServer(
  port: 8080,
  onError: (error, stackTrace, ctx) => error is PaymentDeclined
      ? Response(statusCode: 402, data: {'error': error.reason})
      : Response(statusCode: 500, data: {'error': 'Internal Server Error'}),
);
```

## Authentication

Mark a controller or method `@Protected` and pass a `jwtKey` to the server.
Protected routes require an `Authorization: Bearer <token>` header. `@Public`
opts a single route out of a protected controller.

```dart
@Controller()
@Protected()
class AccountController {
  @Get('/me')
  Future<Response> me() async => Response.json(data: {});

  @Public()
  @Get('/health')
  Future<Response> health() async => Response.json(data: {});
}

final server = RatelServer(port: 8080, jwtKey: 'your-secret');
```

## Middleware

Cross-cutting concerns are composable middleware. Register global middleware on
the server; the JWT auth middleware is appended automatically when `jwtKey` is
set. Built-in middleware comes from `CorsMiddleware.create`,
`SecurityHeadersMiddleware.create`, `RateLimitMiddleware.create` and
`StaticFilesMiddleware.create`.

```dart
final server = RatelServer(
  port: 8080,
  jwtKey: 'your-secret',
  middlewares: [CorsMiddleware.create(), SecurityHeadersMiddleware.create()],
  onStartup: () async => print('starting'),
  onShutdown: () async => print('bye'),
);
```

Role-based access uses `@Protected(roles: ['admin'])`; the caller's `roles` JWT
claim is checked, returning 403 when the role is missing.

## WebSockets

`@Socket` binds a method to WebSocket upgrades on a path. The method receives
the upgraded socket, and the `RequestContext` if it asks for one. Socket paths
match exactly, and upgrades do not run the middleware chain — authenticate
inside the handler, from the query string or the first message.

```dart
@Controller()
class ChatController {
  @Socket('/ws')
  Future<void> chat(WebSocket socket) async {
    socket.listen((message) => socket.add('echo: $message'));
  }
}
```

## API documentation

`OpenApiSpec.build` turns the registered routes into an OpenAPI 3 document. The
generator resolved each handler's inputs at build time, so the spec needs no
reflection and stays in step with the code.

```dart
@Get('/openapi.json')
Future<Response> spec(RequestContext ctx) async =>
    Response.json(
      data: OpenApiSpec.build(ctx.registry.routes, title: 'Orders'),
    );
```

## Scaling across cores

A Dart isolate uses one core. `RatelCluster.run` runs the application's
startup on one isolate per core, and `shared: true` lets every one of them bind
the same port, with the OS spreading connections across them.

```dart
Future<void> main() => RatelCluster.run(AppServer.start);

abstract final class AppServer {
  static void start(List<String> args) {
    RatelServer(port: 8080, shared: true).startServer();
  }
}
```

Isolates share no memory, so the entry point does the whole startup, bindings
and server included, on each one. The routes follow on their own: the cluster
hands every isolate the route manifest the CLI installed.

Files on disk are served by `StaticFilesMiddleware.create`, which falls through to the router
when no file matches and refuses paths that escape the directory.

```dart
final server = RatelServer(
  port: 8080,
  middlewares: [
    StaticFilesMiddleware.create(directory: 'public', urlPrefix: '/assets'),
  ],
);
```

## Configuration

`RatelServer` takes its whole configuration in the constructor:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `port` | `8080` | Port to bind. `0` lets the OS pick a free one; read it back from `boundPort`. |
| `jwtKey` | none | HMAC secret that turns on JWT auth. Without it no route is protected. |
| `securityContext` | none | Serves over TLS. With `jwtKey` set and no TLS, a warning is logged because bearer tokens would travel in cleartext. |
| `middlewares` | `[]` | Run in order around every request. The JWT middleware is appended after them. |
| `bindings` | none | Dependency registrations, run once when the server is constructed. |
| `onStartup` | none | Runs before the port is bound. A throw aborts `startServer`. |
| `onShutdown` | none | Runs during `stop()`, after the socket is closed. |
| `onError` | none | Maps an unhandled error to a response (see [Errors](#errors)). |
| `gzip` | `true` | Compresses responses for clients that send `Accept-Encoding: gzip`. |
| `idleTimeout` | `dart:io` default | Keep-alive idle timeout. |
| `shared` | `false` | Binds the port shared, for `RatelCluster.run`. |
| `maxRequestBodyBytes` | 1 MiB | Larger bodies are answered with `413`. |
| `maxBodyDrainBytes` | 1 MiB | How much of an oversized body is read and discarded so the `413` still reaches the client. |

## Dependency injection

`Injector` holds lazily built singletons. Register factories in a `Bindings`
subclass and pass it to the server. A controller whose constructor takes
arguments is registered in the injector too; Ratel builds it from there, and
builds any other controller through its no-argument constructor:

```dart
class AppBindings extends Bindings {
  @override
  void dependencies() {
    Injector().put<UserService>(() => UserService());
    Injector().put<UserController>(
      () => UserController(Injector().get<UserService>()),
    );
  }
}

final server = RatelServer(port: 8080, bindings: AppBindings());
```

`startServer` checks every controller after `onStartup` and before it binds the
port, and throws a `StateError` naming any controller that is neither
registered nor built with a no-argument constructor.

`Injector()` returns the ambient injector. A test builds an isolated one with
`Injector.scoped()` and installs it as `Injector.ambient`.

## Database

Ratel has no database layer of its own, the way NestJS has none: open whatever
client you use in `onStartup`, close it in `onShutdown`, and hand it to your
controllers through `Bindings`. With [`package:postgres`](https://pub.dev/packages/postgres)
directly:

```dart
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:ratel/ratel.dart';

@Controller()
class UserController {
  UserController(this.pool);

  final Pool pool;

  @Get('/users/:id')
  Future<Response> byId(@PathParam('id') int id) async {
    final result = await pool.execute(
      Sql.named('SELECT id, name FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) throw const NotFoundException();
    return Response.json(data: result.first.toColumnMap());
  }
}

class AppBindings extends Bindings {
  AppBindings(this.pool);

  final Pool pool;

  @override
  void dependencies() {
    Injector().put<UserController>(() => UserController(pool));
  }
}

Future<void> main() async {
  final pool = Pool.withUrl(Platform.environment['DATABASE_URL']!);
  final server = RatelServer(
    port: 8080,
    bindings: AppBindings(pool),
    onShutdown: pool.close,
  );
  await server.startServer();
}
```

Under `RatelCluster.run`, each isolate builds its own client inside the entry
function. For repositories, migrations and a query builder, add
[`ratel_orm`](https://pub.dev/packages/ratel_orm), which works with or without Ratel. Its README
shows the same wiring with `RatelRepository`.

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
