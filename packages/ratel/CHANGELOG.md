# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org).

## 2.0.0-dev.8 (unreleased)

### Removed
- **`@Json` is gone** (breaking). JSON conversion is discovered from the route
  signatures, the way Spring does with Jackson: the type of every `@Body()`
  parameter is decoded, every route's return type is encoded (through
  `Future`, `Response<T>` and collections), and so is every class their
  fields reach. To migrate, delete the annotations; a leftover `@Json()` fails
  the build with a hint saying so. A class that a route sends only through a
  raw `Response` needs the route to return it, or `Response<T>` of it, since a
  raw `Response` hides the payload type:
  ```dart
  @Post('/')
  Future<Response<Item>> create(@Body() Item item) async =>
      Response.json(statusCode: 201, data: item);
  ```
- **One declaration per file, no top-level functions** (breaking renames). The
  public API is the same, reached through classes:
  - `corsMiddleware` → `CorsMiddleware.create`,
    `securityHeadersMiddleware` → `SecurityHeadersMiddleware.create`,
    `rateLimitMiddleware` → `RateLimitMiddleware.create`,
    `staticFiles` → `StaticFilesMiddleware.create`,
    `jwtAuthMiddleware` → `JwtAuthMiddleware.create`.
  - `openApiSpec` → `OpenApiSpec.build`.
  - The token checker class `JwtAuthMiddleware` is now `JwtValidator`.
  - `ratelLogger` is no longer exported; `Logger('ratel')` returns the same
    logger.
  - `Router`, `RouteMatch`, `splitPath` and `normaliseSocketPath` were
    internals and are no longer exported.
  - The sources live under `lib/src`. `package:ratel/ratel.dart` exports
    the public API, and `package:ratel/runtime.dart` exports what generated
    code uses.
- **The registration API that only generated code used** (breaking):
  - `RatelHandler` and its statics, and `RatelRegistry.current`,
    `runScoped` and `reset`.
  - `RatelControllers` (use `Injector().put`), `RatelJson` (codecs travel
    with the manifest), and `runCluster` (use `RatelCluster.run`).
  - The top-level `coerceParam`, `cookieValue`, `readBodyLimited`,
    `decodeBody`, `decodeJsonObject` and `readMultipart`.
  - A `RouteHandler` is now `Future<Object?> Function(RequestContext ctx)`,
    and `RequestContext` takes its registry explicitly.
  - Body limits live on `RequestContext.limits` instead of the registry.
- **A server without routes refuses to start** (breaking). `RatelServer`
  without a `registry:` needs the route manifest the `ratel` CLI installs,
  and a plain `dart run` fails before binding, with a message pointing at
  `ratel dev`, instead of answering every request with 404. Pass
  `registry: RatelRegistry()..register(Route(...))` to serve hand-built
  routes.
- **No more build_runner, generated files or `$registerRatel()`** (breaking).
  Controllers are discovered by `@Controller` and wired by the `ratel` CLI,
  which reads them with the Dart analyzer and keeps the wiring under
  `.dart_tool/ratel/`. It finds controllers in `lib/` and next to the
  entrypoint even when nothing imports them. `ratel_generator` is retired.
  To migrate:
  - Annotate each controller with `@Controller()`; `extends RatelHandler` is
    no longer needed.
  - Register a controller that takes constructor arguments with
    `Injector().put<C>(() => C(...))` instead of `RatelControllers.register`.
  - Delete the `*.ratel.dart` files and drop `build_runner` and
    `ratel_generator` from `dev_dependencies`. `ratel dev` lists any it
    finds.
- **The `ratel` executable moved to the `ratel_cli` package** (breaking for
  installs): `dart pub global deactivate ratel`, then
  `dart pub global activate ratel_cli`. Applications no longer carry the CLI in
  their dependency graph.
- **The framework has no database layer any more** (breaking). `RatelDriver`,
  `RatelSession`, `QueryResult`, the database exceptions, `Db`,
  `RatelServer(database:)` and `server.db` moved to or were replaced in
  `ratel_orm`, which no longer depends on `ratel`. Open a client in `onStartup`,
  close it in `onShutdown` and provide it through `Bindings`. The README shows
  this with `package:postgres`, and `ratel_orm`'s README shows it with
  `RatelRepository`.

### Added
- **Typed JSON decoding.** Generated decoders build a class through its public
  unnamed constructor, so immutable DTOs with final fields and a `const`
  constructor work, as do nested classes, `List`, `Set` and `Map<String, T>`
  fields, enums, `DateTime`, `Uri`, `BigInt` and generic instantiations such
  as `Page<Item>`. A missing key falls back to the parameter's default value
  or `null`, and a missing required field or a value of the wrong type answers
  400 naming the field: `Field "id" is required`,
  `Field "id" must be an integer`. The decoders read values through
  `JsonValues`, exported from `package:ratel/runtime.dart`, which also accepts
  numbers and booleans written as strings, so form-urlencoded and multipart
  bodies decode into the same DTOs. A blank form value for a number, `bool`,
  `DateTime`, `BigInt` or enum counts as missing, and a checkbox's `on` reads
  as `true`. A multipart body binds to a `@Body()` DTO even when the route
  takes no `MultipartData`.
- **Typed JSON encoding.** Generated encoders convert nested classes,
  collections, enums (by `name`), `DateTime` (ISO-8601), `Uri` and `BigInt`
  field by field instead of looking each value up at runtime.
- **Hand-written `toJson` and `fromJson` still win.** A class that declares
  `toJson()` is encoded through it, and one with a
  `fromJson(Map<String, dynamic>)` constructor is decoded through it, so
  `json_serializable` and `freezed` classes, abstract ones included, keep
  their key names.
- `Response` is generic. `Response<T>` types its `data` and keeps the type
  through `withHeaders` and `withCookie`, the way Spring's `ResponseEntity<T>`
  does, so a handler can declare `Future<Response<Item>>`. A raw `Response` is
  `Response<dynamic>` and works as before.
- **The route manifest runtime** (`package:ratel/runtime.dart`): const
  `ControllerDefinition`, `RouteDefinition`, `SocketDefinition` and
  `JsonCodecDefinition` values that `RatelRegistry.fromManifest` binds into
  routes. All request binding now lives in the runtime, where plain `dart test`
  can exercise it with hand-built definitions: parameter coercion, JSON and form
  bodies, multipart, `RequestContext` injection and sockets. This is the target
  the `ratel` CLI will generate against, so generation never has to be visible.
- `@Controller()` takes an optional prefix, `Injector.contains<T>()` reports a
  registration, and `RatelCluster.run` forwards the installed manifest to every
  isolate (`runCluster` delegates to it).
- `RatelManifest.isolateSetup` lists `void Function()` hooks that
  `RatelRuntime.install` runs once per isolate, on the first install, so every
  `RatelCluster.run` isolate runs them too. The `ratel` CLI uses it to install
  the `ratel_orm` entity manifest next to the route manifest; `ratel` itself
  knows nothing about the ORM.
- Request body limits travel on `RequestContext.limits` as `RequestLimits`,
  owned by the server that set them.
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
- **Static file serving.** `staticFiles(directory: ..., urlPrefix: ...)` is a
  middleware that answers `GET` requests from a directory on disk and falls
  through to the router when no file matches. Content types come from
  `package:mime`, and a request that resolves outside the directory — `..`
  segments or a symlink leaving the tree — gets a `404` instead of the file.
- **Server-Sent Events.** `Response.sse(stream)` streams a `Stream<String>` as
  `text/event-stream`, one `data:` frame per value, until the stream closes. The
  response opens with an SSE comment so the client gets its headers immediately,
  and declines compression so a gzip buffer cannot hold events back.
- **`RatelServer(onError: ...)`**, a hook that maps an error no route handled
  onto a `Response` of the application's choosing — the seam where a domain
  exception becomes an HTTP status. The error is still logged with its
  correlation id first, and a hook that throws falls back to the generic `500`.
- **`Response.withCookie`**, which attaches a `Set-Cookie` header built from a
  `dart:io` `Cookie`, so a response can carry flags like `httpOnly`, `secure`
  and `sameSite`. Cookies survive `withHeaders`, so decorating middleware does
  not drop them.

### Changed
- A `Set` or any other `Iterable` in a JSON response is encoded as an array,
  and `RatelSerializationException` explains which route signatures make Ratel
  generate an encoder.
- **The source carries no comments, dartdoc included.** The README now documents
  the server configuration and dependency injection that only the API reference
  used to describe.
- **Routes, sockets and the request body limit are held by a `RatelRegistry`
  rather than by statics on `RatelHandler`** — the prerequisite for running more
  than one server in an isolate, and for `runCluster`. A server adopts the
  ambient registry unless given one, so nothing changes for an application with
  a single server; `RatelServer(registry: ...)` opts out. A handler reads its
  limit from `ctx.registry`, so the last server constructed no longer decides
  the body limit for every other one.
- **`Injector` can be scoped.** `Injector.scoped()` builds an isolated one,
  `Injector.ambient` chooses which `Injector()` hands out, and `clear()` forgets
  its registrations — so a test no longer inherits another test's bindings.
- The server's error correlation counter is per server rather than per process.
- The oversized-body drain bound is per server too: `RatelServer(maxBodyDrainBytes:
  ...)` sets it, `ctx.registry.maxBodyDrainBytes` is what a handler reads, and
  `RatelHandler.maxBodyDrainBytes` stays as a facade over the ambient registry.

### Fixed
- Malformed request input now answers 400 instead of logging SEVERE and
  answering 500. This covers a body that is not valid UTF-8, a bad
  percent-escape in a form body or query parameter, and a truncated or garbled
  multipart body, which could also hang the request or throw an uncaught error.
- Text responses are now always sent as UTF-8: JSON, text, HTML and Server-Sent
  Events declare `charset=utf-8`, and any `text/*`, JSON or `+json` content type
  you set gets it too. Before, characters such as "ã" arrived garbled and
  characters outside Latin-1 (for example "日本" or emoji) could leave the request
  hanging; a response whose headers or event stream fail is now always closed.
- @Protected now applies to @Socket routes. A socket on a @Protected controller,
  or with its own @Protected, was upgraded for anyone. `SocketDefinition` takes
  `isProtected` and `requiredRoles`, and when `jwtKey` is set `RatelServer`
  refuses the upgrade with 401 or 403 and passes the token's claims to the
  socket's `RequestContext`. `RatelRegistry.socketFor` now returns a
  `SocketRoute`.
- `startServer` now fails before binding the port when a controller can be
  neither built from the injector nor through a no-argument constructor. Before,
  the server started and every request to that controller answered 500.
- `Injector.put` now drops any instance already cached for that type. The next
  `get` builds from the new factory instead of returning the old instance.
- `RatelServer.stop()` is now idempotent: calling it again, or a SIGINT arriving
  mid-shutdown, waits for the shutdown already running. It no longer runs
  `onShutdown` a second time or throws a `ConcurrentModificationError`. The 404
  for a WebSocket upgrade on an unknown path is now awaited.
- A multipart upload over `maxRequestBodyBytes` now gets its 413 instead of a
  connection reset. The parser reads and discards the rest of the body, up to
  `maxBodyDrainBytes`, before rejecting it, and adds `Connection: close` when
  the body goes past that bound too, the same as plain request bodies.
- `Response.send` now encodes the body before writing any headers. A body the
  serializer cannot encode, such as an object with no JSON codec and no
  `toJson`, now gets a 500 with a logged correlation id instead of leaving the
  client hanging. JSON bodies are recognised even when the content type carries
  parameters such as `; charset=utf-8`, and a null body is no longer sent as the
  text `null`.
- A missing required path, query, header or cookie parameter now gets a 400 that
  names the parameter instead of a 500. A JSON body whose field types do not
  match the model (for example `"id":"x"` for an int field) now gets a 400 that
  names the field instead of a 500.
- OpenAPI output is now valid for routes that require roles. The bearerAuth
  security requirement uses an empty scope list, as OpenAPI 3.0 requires for
  http bearer schemes. The roles now appear in an `x-required-roles` extension
  on the operation.
- CorsMiddleware no longer joins every allowed origin into one
  Access-Control-Allow-Origin header, which browsers reject. With an origin list
  it echoes the request's Origin when it is allowed and adds Vary: Origin, sends
  no CORS headers to other origins, and still sends '*' when the wildcard is
  configured. It now answers only real preflights (OPTIONS carrying Origin and
  Access-Control-Request-Method) itself, so @Options routes and 405 responses
  work again.
- `HEAD` on a `Response.sse` route answers with the stream's headers and closes,
  instead of streaming the body a `HEAD` must not carry.
- Requests are dispatched concurrently. The serve loop used to `await` each
  request before accepting the next, so a single slow handler — or an open
  event stream — blocked every other client.

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
