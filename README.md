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
| [`ratel`](packages/ratel) | `2.0.0-dev.8` | The HTTP framework: routing, DI, JWT and middleware. It has no database layer. |
| [`ratel_cli`](packages/ratel_cli) | `2.0.0-dev.8` | The `ratel` command: `create`, `dev` and `build`. It discovers controllers with the Dart analyzer and keeps the wiring under `.dart_tool/`. Installed globally, released in lockstep with `ratel`. |
| [`ratel_orm`](packages/ratel_orm) | `0.1.0-dev.1` | The driver contract, the Postgres and SQLite drivers, repositories with explicit row mapping, a query builder, dialects and migrations. It does not depend on `ratel`. |

The framework and the ORM are independent, like NestJS and Prisma. An HTTP app
can talk to its database through any client, and a plain Dart program can use
`ratel_orm` without pulling in an HTTP framework. Used together, the server's
startup and shutdown hooks open and close the driver, and dependency injection
hands repositories to controllers.

## Quick start

```sh
dart pub global activate ratel_cli
ratel create my_api
cd my_api
ratel dev
```

See [`packages/ratel/README.md`](packages/ratel/README.md) for routing,
authentication, middleware and database usage.

## Working on this repository

The packages form a single [pub workspace](https://dart.dev/tools/pub/workspaces),
so one resolve covers all of them and they see each other without path
dependencies:

Nothing is generated into the source tree, so a fresh clone analyzes and tests
right after `dart pub get` at the root:

```sh
dart pub get
dart analyze
(cd packages/ratel && dart test)
(cd packages/ratel_cli && dart test)
(cd packages/ratel_orm && dart test)
```

The `ratel_cli` tests include end-to-end runs tagged `e2e`: they compile the
CLI, scaffold an app, build it and drive `ratel dev`. Skip them with
`dart test -x e2e`. The fixture apps under `packages/ratel_cli/test/fixtures`
are workspace members so they resolve with everything else. Requires the Dart
SDK `3.6.0` or newer.

The Postgres tests in `ratel_orm` skip themselves unless `DB_HOST` is set, and
they are the only tests that exercise the driver's real wire protocol. CI runs
them against a Postgres 16 service. CI also compiles the example to a native
binary, so anything that breaks ahead-of-time compilation fails there rather
than in a user's deployment.

The code carries no comments of any kind. Explanations belong in these READMEs,
in the CHANGELOGs and in pull request descriptions.

## License

[MIT](LICENSE)
