<h1 align="center">Ratel</h1>

<p align="center">
    <img
    align="center"
    height="200"
    src="./packages/ratel/assets/Ratel.png"/>
</p>

<p align="center">
  A lightweight, annotation-driven backend framework for Dart — and the
  packages built around it.
</p>

> **Status:** the `2.0.0-dev` line is an active hardening effort. APIs are
> changing. For the stable API use `ratel` `1.0.3`.

## Packages

| Package | Version | What it is |
|---|---|---|
| [`ratel`](packages/ratel) | `2.0.0-dev.8` | The HTTP framework: routing, DI, JWT, middleware, and the `ratel` CLI. It has no database layer. |
| [`ratel_orm`](packages/ratel_orm) | `0.1.0-dev.1` | The driver contract, the Postgres and SQLite drivers, repositories with explicit row mapping, a query builder, dialects and migrations. It does not depend on `ratel`. |
| [`ratel_generator`](packages/ratel_generator) | `0.1.0-dev.1` | The `build_runner` generator that replaces `dart:mirrors`, so applications compile with `dart compile exe`. Wired in for you by the CLI. |

The framework and the ORM are independent, like NestJS and Prisma. An HTTP app
can talk to its database through any client, and a plain Dart program can use
`ratel_orm` without pulling in an HTTP framework. Used together, the server's
startup and shutdown hooks open and close the driver, and dependency injection
hands repositories to controllers.

## Quick start

```sh
dart pub global activate ratel
ratel create my_api
cd my_api
ratel dev
```

See [`packages/ratel/README.md`](packages/ratel/README.md) for routing,
authentication, middleware and database usage.

## Working on this repository

The three packages form a single [pub workspace](https://dart.dev/tools/pub/workspaces),
so one resolve covers all of them and they see each other without path
dependencies:

Run `dart pub get` once at the root, generate code in the two packages that use
it, then analyze the whole workspace and test each package:

```sh
dart pub get
(cd packages/ratel && dart run build_runner build --delete-conflicting-outputs)
(cd packages/ratel_orm && dart run build_runner build --delete-conflicting-outputs)
dart analyze
(cd packages/ratel && dart test)
```

Generated `*.ratel.dart` files sit next to their sources and are gitignored, so
**code generation has to run before `dart analyze` or `dart test`** on a fresh
clone. Requires the Dart SDK `3.6.0` or newer.

The Postgres tests in `ratel_orm` skip themselves unless `DB_HOST` is set, and
they are the only tests that exercise the driver's real wire protocol. CI runs
them against a Postgres 16 service. CI also compiles the example to a native
binary, so anything that breaks ahead-of-time compilation fails there rather
than in a user's deployment.

The code carries no comments of any kind. Explanations belong in these READMEs,
in the CHANGELOGs and in pull request descriptions.

## License

[MIT](LICENSE)
