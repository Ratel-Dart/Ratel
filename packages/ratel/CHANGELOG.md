# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org).

## 2.0.0-dev.8 (unreleased)

### Added
- **OpenAPI 3 generation.** `openApiSpec(routes)` builds a spec document from
  the registered routes — `:id` becomes `{id}`, every bound parameter becomes an
  operation parameter with its location and type, a `@Body` route gains a JSON
  request body, and a `@Protected` route carries its roles as a `bearerAuth`
  requirement:
  ```dart
  @Get('/openapi.json')
  Future<Response> spec(RequestContext ctx) async =>
      Response.json(data: openApiSpec(ctx.registry.routes, title: 'Orders'));
  ```
  A `Route` now carries the `parameters` and `bodyType` the generator resolved
  at build time, so the spec is produced without reflection.
- **`RequestContext` injection.** A handler parameter typed `RequestContext`
  receives the context for the request — the raw `HttpRequest`, the matched
  route, the path parameters, the JWT claims and the middleware state bag — with
  no annotation:
  ```dart
  @Get('/me')
  Future<Response> me(RequestContext ctx) async =>
      Response.json(data: {'sub': ctx.claims?['sub']});
  ```
- **WebSocket routes.** `@Socket('/path')` binds a controller method to
  WebSocket upgrades on that path; the method receives the upgraded `WebSocket`
  and, if it asks for one, the `RequestContext`. Socket paths match exactly and
  upgrades bypass the middleware chain, so a socket authenticates itself inside
  its handler:
  ```dart
  @Socket('/ws')
  Future<void> chat(WebSocket socket) async {
    socket.listen((message) => socket.add('echo: $message'));
  }
  ```
- **Multi-isolate scaling.** `runCluster(entryPoint)` runs an application's
  startup on one isolate per CPU core, and `RatelServer(shared: true)` binds the
  port so they can all listen on it and the OS spreads connections across them:
  ```dart
  void main() => runCluster(serve);

  void serve(List<String> args) {
    $registerRatel();
    RatelServer(port: 8080, shared: true).startServer();
  }
  ```
- **`multipart/form-data` parsing.** A handler parameter typed `MultipartData`
  receives the parsed body — text `fields` and uploaded `files` — with the
  request size limit enforced across every part:
  ```dart
  @Post('/avatar')
  Future<Response> avatar(MultipartData form) async {
    final file = form.file('avatar');
    return Response.json(data: {'bytes': file?.bytes.length});
  }
  ```
- **Automatic `HEAD` handling.** A `HEAD` request with no `@Head` route of its
  own falls back to the `GET` route for the same path and answers with its
  status and headers but no body. An explicit `@Head` route still wins.

### Changed
- **Routes, sockets and the request body limit are held by a `RatelRegistry`
  rather than by statics on `RatelHandler`** — the prerequisite for running more
  than one server in an isolate, and for `runCluster`. A server adopts the
  ambient registry unless given one, so nothing changes for an application with
  a single server; `RatelServer(registry: ...)` opts out. A handler reads its
  limit from `ctx.registry`, so the last server constructed no longer decides
  the body limit for every other one.
- **`server.db` runs on the server's own driver** instead of the last driver
  passed to `Db.configure`. `Db.driver` stays ambient for the ORM repository,
  which resolves through it.
- **`Injector` can be scoped.** `Injector.scoped()` builds an isolated one,
  `Injector.ambient` chooses which `Injector()` hands out, and `clear()` forgets
  its registrations — so a test no longer inherits another test's bindings.
- The server's error correlation counter is per server rather than per process.

## 2.0.0-dev.7 (unreleased)

### Added
- **A `ratel` command line tool.** `ratel create` scaffolds an application,
  `ratel dev` runs it and restarts on change, and `ratel build` compiles a
  native binary to `build/server`. Install with `dart pub global activate ratel`.
- **`RatelControllers`**, so a controller can take its dependencies through its
  constructor. Register a factory from `Bindings.dependencies()` and the
  generated route table builds the controller with it:
  ```dart
  RatelControllers.register<UserController>(
    () => UserController(Injector().get<UserService>()),
  );
  ```
  Controllers with a no-argument constructor need no registration.

### Fixed
- A response payload with no serializer no longer serializes silently as
  `"Instance of 'Foo'"`; it now raises an error naming the type. `DateTime`,
  `Enum`, `Uri` and `BigInt` gained explicit representations rather than
  relying on `toString()` by accident.
- A controller that failed to register its routes no longer starts a server that
  silently 404s everything — registration is no longer something an application
  can forget.

### Changed
- **The database layer is now driver-based and database-agnostic** (breaking).
  `RatelServer(database: ...)` accepts a `RatelDriver` instead of a
  `RatelDatabase`, opens and closes it with the server lifecycle, and exposes
  raw SQL via `server.db` (`server.db.query(sql, parameters: ...)`, run
  verbatim). The driver contract — `RatelDriver`, `QueryResult`, `RatelSession`,
  `transaction`, and the `DatabaseException` hierarchy — now lives in the core.
- **`dart:mirrors` is gone; the framework is now AOT-compilable** (breaking).
  Routing, controller wiring and JSON serialization are resolved at build time
  instead of by reflection, so an app compiles to a native binary. The `ratel`
  CLI performs that step, so there is no build command to run by hand and no
  generated code to reference:
  - Run the app with `ratel dev`, and compile it with `ratel build`.
  - `RatelServer` no longer takes `handlers:` — annotated controllers are found
    automatically.
  - `@Json` classes need no `part` directive, no `toJson()` and no `fromJson`
    factory. Write the class; the rest is generated.
  - Controllers and `@Json`/`@Column` classes must be **public**, since the
    generated code lives in a separate library. A private one is now a build
    error naming the class.
- `Response.json`, `.text`, `.html` and `.bytes` default `statusCode` to `200`.

### Removed
- **`package:postgres` is no longer a dependency of `ratel`** (breaking).
  `RatelDatabase`, `RatelRepository` and `@Column` were removed from the core;
  the ORM and the Postgres driver moved to the separate `ratel_orm` package
  (`PostgresDriver` from `package:ratel_orm/postgres.dart`). Repository writes no
  longer auto-append `RETURNING *`; add it explicitly. See
  [`doc/migration-2.0-database.md`](doc/migration-2.0-database.md).
- The `ratel.sh` script, superseded by the `ratel` CLI
  (`dart pub global activate ratel`).
- **The outbound HTTP client** (`Request`, `ApiResponse`) and its exceptions
  `HttpRequestException`, `HttpResponseException` and `JsonDecodingException`
  (breaking). It was exported but unused, untested, and leaked its `HttpClient`
  on the error path. Use `package:http` or `dart:io`'s `HttpClient` directly.

## 2.0.0-dev.6 (unreleased)

### Added
- Response gzip compression (`RatelServer(gzip: ...)`, on by default) when the
  client advertises `Accept-Encoding: gzip`.
- Configurable connection `idleTimeout` on `RatelServer`.
- `@Header('Name')` and `@CookieParam('name')` handler parameter injection.

### Fixed
- `null` values now serialize as JSON `null` instead of the string `"null"`.
- `Response.bytes` now writes a raw binary body instead of `data.toString()`.

## 2.0.0-dev.5 (unreleased)

### Added
- `rateLimitMiddleware` — fixed-window per-IP rate limiting that returns `429`
  with a `Retry-After` header once the limit is exceeded.

## 2.0.0-dev.4 (unreleased)

### Added
- `application/x-www-form-urlencoded` request body parsing (selected by
  `Content-Type`, in addition to JSON).
- `Response.redirect(location, {statusCode})` helper.

## 2.0.0-dev.3 (unreleased)

### Added
- Dynamic path parameters: `@PathParam('id')` binds `:id` segments (e.g.
  `/users/:id`), with type coercion and a 400 on invalid values.
- `@Controller('/prefix')` to prefix every route in a controller.
- `@Patch`, `@Head` and `@Options` method annotations.
- `405 Method Not Allowed` with an `Allow` header when the path exists for other
  methods (previously a 404).
- A `Router` (exported) that resolves `(method, path)` with path parameters and
  reports allowed methods.

### Changed
- Route handlers now receive the `RequestContext` (exposing `pathParams` and
  the authenticated `claims`).

## 2.0.0-dev.2 (unreleased)

### Added
- Middleware pipeline (`Middleware` / `Next`) with global middleware on
  `RatelServer`; the JWT auth check is now a middleware.
- `RequestContext` carrying the matched route, JWT claims and per-request state.
- Built-in `corsMiddleware` (incl. `OPTIONS` preflight) and
  `securityHeadersMiddleware`.
- Role-based authorization: `@Protected(roles: [...])` returns 403 when the
  caller lacks the role.
- Server lifecycle: `stop()`, `onStartup` / `onShutdown` hooks, SIGINT/SIGTERM
  handling, and `boundPort` (bind to port `0` in tests).
- Duplicate `path`+`method` route detection at startup.

### Changed
- JWT claims are exposed via `RequestContext` instead of being discarded.
- `startServer()` now returns once listening; serving continues in the
  background.

## 2.0.0-dev.1 (unreleased)

Start of the 2.0 line — a hardening and modernization effort. This pre-release
covers the foundation work; APIs are still in flux and breaking changes are
expected before 2.0.0.

### Changed
- Renamed `annotations/geral_annotations.dart` to `annotations/annotations.dart`
  (**breaking** import path change).
- Standardized all framework-emitted messages on English.
- Replaced `print` with the `logging` package (`Logger('ratel')`, exported as
  `ratelLogger`); applications configure their own handler.

### Removed
- Dead code: the unused `HttpMethod` and `Auth` classes.
- The unused `reflectable` dependency.

### Fixed
- Empty `catch` blocks in response serialization now log the failure instead of
  silently dropping fields.

### Tooling
- Added `.gitignore`; stopped tracking `.dart_tool/` and `pubspec.lock`.
- Added `analysis_options.yaml` (lints) and a `dev_dependencies` block.
- Added a test suite and a GitHub Actions CI pipeline.

## 1.0.2

- Update documentation.
