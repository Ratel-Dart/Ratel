# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org).

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
