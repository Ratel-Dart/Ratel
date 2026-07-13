# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org).

## 2.0.0-dev.6 (unreleased)

### Added
- Response gzip compression (`RatelServer(gzip: ...)`, on by default) when the
  client advertises `Accept-Encoding: gzip`.
- Configurable connection `idleTimeout` on `RatelServer`.
- `@Header('Name')` and `@CookieParam('name')` handler parameter injection.

### Fixed
- `null` values now serialize as JSON `null` instead of the string `"null"`.
- `Response.bytes` now writes a raw binary body instead of `data.toString()`.

### Changed
- **The database layer is now driver-based and database-agnostic** (breaking).
  `RatelServer(database: ...)` accepts a `RatelDriver` instead of a
  `RatelDatabase`, opens and closes it with the server lifecycle, and exposes
  raw SQL via `server.db` (`server.db.query(sql, parameters: ...)`, run
  verbatim). The driver contract — `RatelDriver`, `QueryResult`, `RatelSession`,
  `transaction`, and the `DatabaseException` hierarchy — now lives in the core.

### Removed
- **`package:postgres` is no longer a dependency of `ratel`** (breaking).
  `RatelDatabase`, `RatelRepository` and `@Column` were removed from the core;
  the ORM and the Postgres driver moved to the separate `ratel_orm` package
  (`PostgresDriver` from `package:ratel_orm/postgres.dart`). Repository writes no
  longer auto-append `RETURNING *`; add it explicitly. See
  [`doc/migration-2.0-database.md`](doc/migration-2.0-database.md).

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
