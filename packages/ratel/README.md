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
- **JSON bodies without boilerplate**: request and response classes are
  converted by code generated from the route signatures, with no annotation
- **No database lock-in**: the framework has no database layer, so any client
  plugs in through dependency injection and the startup and shutdown hooks.
  The separate [`ratel_orm`](https://github.com/Ratel-Dart/ratel_orm) package is
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

A DTO and a controller, each in its own file, are all the code there is.
`lib/dtos/greeting.dart`:

```dart
final class Greeting {
  const Greeting({required this.message});

  final String message;
}
```

`lib/controllers/hello_controller.dart`:

```dart
import 'package:my_api/dtos/greeting.dart';
import 'package:ratel/ratel.dart';

@Controller()
class HelloController {
  @Get('/hello')
  Future<Greeting> hello(@Param() String? name) async =>
      Greeting(message: 'Hello, ${name ?? 'world'}!');

  @Post('/echo')
  Future<Response<Greeting>> echo(@Body() Greeting body) async =>
      Response.json(statusCode: 201, data: body);
}
```

The entrypoint in `bin/server.dart` only starts the server:

```dart
Future<void> main() async {
  final server = RatelServer(port: 8080);
  await server.startServer();
}
```

`curl "http://localhost:8080/hello?name=Ada"` answers
`{"message":"Hello, Ada!"}`. `Greeting` needs no annotation: Ratel converts
it because a route returns it and takes it as `@Body()` (see [JSON](#json)).

`ratel dev` restarts the server on every change. A complete runnable version
lives in [`example/`](example): `main.dart` starts the server, and the
controller and the DTO sit in their own folders, found without any import.

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

A handler returns a value, which is sent as a `200` JSON response, or a
`Response` when it needs another status, headers or representation.
`Response<T>` carries the payload type, the way Spring's `ResponseEntity<T>`
does, so Ratel still knows which class to encode (see [JSON](#json)):

```dart
@Post('/')
Future<Response<Item>> create(@Body() Item item) async =>
    Response.json(statusCode: 201, data: item);
```

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

Text is always sent as UTF-8. The JSON, text, HTML and event-stream responses
declare `charset=utf-8`, a `text/*`, JSON or `+json` content type of your own
gets it too, and a string body is labelled UTF-8 whatever charset was given. To
send another encoding, encode the body yourself and return it as bytes.

A handler streams Server-Sent Events by returning `Response.sse`. Each value of
the stream is sent as one `data:` frame and the connection stays open until the
stream closes.

```dart
@Get('/prices')
Future<Response> prices() async => Response.sse(priceTicks.map(jsonEncode));
```

## JSON

Ratel converts bodies to and from JSON with code the CLI generates from the
route signatures, the way Spring does with Jackson. There is no annotation, and
no `toJson` or `fromJson` to write. The generated code starts from:

- the type of every `@Body()` parameter, which is decoded from the request;
- the return type of every route, which is encoded into the response. Ratel
  looks through `Future<T>`, `FutureOr<T>`, `Response<T>` and the elements
  of a `List`, `Set`, `Iterable` or `Map<String, T>`.

From there it follows the fields of each class, however deep they nest:

```dart
enum Status { draft, published }

final class Tag {
  const Tag({required this.name});

  final String name;
}

final class Article {
  const Article({
    required this.id,
    required this.title,
    this.tags = const [],
    this.status = Status.draft,
    this.publishedAt,
  });

  final int id;
  final String title;
  final List<Tag> tags;
  final Status status;
  final DateTime? publishedAt;

  String get slug => title.toLowerCase().replaceAll(' ', '-');
}

@Controller('/articles')
class ArticleController {
  @Get('/:id')
  Future<Article> byId(@PathParam('id') int id) async =>
      Article(id: id, title: 'Hello Ratel');

  @Get('/')
  Future<List<Article>> all() async => const [];

  @Post('/')
  Future<Response<Article>> create(@Body() Article article) async =>
      Response.json(statusCode: 201, data: article);
}
```

`GET /articles/1` answers:

```json
{"id":1,"title":"Hello Ratel","tags":[],"status":"draft","publishedAt":null,"slug":"hello-ratel"}
```

**Types.** `String`, `int`, `double`, `num` and `bool` map to their JSON
counterparts, `DateTime` to an ISO-8601 string, `Uri` and `BigInt` to strings,
and an enum to its `name`. `List`, `Set` and `Iterable` become arrays,
`Map<String, T>` becomes an object, and `Object` or `dynamic` passes through
as is. Every one of them may be nullable. Records, functions, streams, maps
with keys other than `String`, abstract and sealed classes, and a generic
class that nests itself with growing type arguments (a `Node<List<T>>` field
inside `Node<T>`) are build errors that name the path to the field. A record
field `range` on `Article` would report:

```
ArticleController.byId -> Article.range has type (int, int), which Ratel cannot convert to JSON.
```

**Encoding.** Every public field and getter, inherited ones included, becomes
a key of the same name, so `slug` above is part of the response.

**Decoding.** Ratel calls the public unnamed constructor, which may be a
factory, and passes each parameter the key of the field it sets: `this.id`,
`super.id`, or a plain parameter named like a field. That makes immutable
DTOs, with final fields and a `const` constructor, the natural shape. When a
key is missing:

- a required, non-nullable parameter answers `400`;
- a nullable parameter gets `null`;
- an optional parameter gets its default value. A non-nullable one also gets
  it when the key holds `null`.

A public mutable field the constructor does not set is assigned when its key
is present. A `late` field without an initializer is always assigned, so a
missing key answers `400` unless the field is nullable. A class that only
travels out needs no constructor at all.

**Your own `toJson` and `fromJson`.** A class that declares a `toJson()`
method is encoded by calling it, and one with a `fromJson(Map<String, dynamic>
json)` constructor is decoded through it, so classes from `json_serializable`
or `freezed` keep their key names. Such a class may be abstract.

**Errors.** A body that does not fit answers `400` and names the field:

```
{"error":"Field \"id\" is required"}
{"error":"Field \"id\" must be an integer"}
{"error":"Field \"status\" must be one of draft, published"}
```

**Forms.** `application/x-www-form-urlencoded` and `multipart/form-data`
fields are strings, so a scalar is also read from a string: `"3"` is an
`int`, `"1.5"` a `double`, and `"true"` or a checked checkbox's `"on"` a
`bool`. A blank value for a number, `bool`, `DateTime`, `BigInt` or enum
counts as a missing key, so an empty optional input leaves the field `null`
or at its default. The same DTO serves a JSON body and a form. The uploaded
files of a multipart body need a `MultipartData` parameter next to the
`@Body()` one.

**`Response<T>`.** Return the DTO itself for a `200`, and `Response<T>` when
the route needs a status or headers. A raw `Response` still sends maps, lists
and strings, but it hides the payload type, so no encoder comes from it: a
class that only ever travels in a raw `Response` fails with a
`RatelSerializationException` unless it declares its own `toJson()`. The
encoder is chosen by the exact runtime class, so return the class the
signature declares rather than a subclass.

**Generics.** Each instantiation a signature uses gets its own codec:
`Future<Page<Article>>` generates one for `Page<Article>`, with the `items`
of a `final List<T> items` field encoded as `Article`s.

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
function.

For repositories, migrations and a query builder, add
[`ratel_orm`](https://github.com/Ratel-Dart/ratel_orm), which works with or
without Ratel. Mark a class `@Entity()` and give it a repository; the `ratel`
CLI generates the row mapping when it runs, builds or tests the app:

```dart
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'users')
final class User {
  const User({this.id, required this.name});

  @Id()
  final int? id;
  final String name;
}

final class UserRepository extends RatelRepository<User, int> {
  UserRepository(super.driver);
}

@Controller('/users')
class UserController {
  UserController(this.users);

  final UserRepository users;

  @Get('/:id')
  Future<User> byId(@PathParam('id') int id) async =>
      await users.findById(id) ?? (throw const NotFoundException());
}
```

Wire it like the example above: register
`UserController(UserRepository(driver))` in `Bindings`, and pass
`onStartup: driver.open` and `onShutdown: driver.close` for a `PostgresDriver`
or `SqliteDriver`. Every `RatelCluster.run` isolate gets the entity mapping
along with the routes. The ORM's README covers columns, naming and
migrations.

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
