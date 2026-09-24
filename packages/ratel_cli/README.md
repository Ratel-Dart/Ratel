<h1 align="center">Ratel CLI</h1>

The `ratel` command for [Ratel](https://github.com/Ratel-Dart/Ratel)
applications. Install it once:

```sh
dart pub global activate ratel_cli
```

| Command | What it does |
| --- | --- |
| `ratel create <name>` | Scaffold a new application. |
| `ratel dev [entrypoint] [-- args]` | Run the app and restart it on every change. Arguments after `--` reach the app's `main`. |
| `ratel build [entrypoint]` | Compile a native binary into `build/`. |
| `ratel test [paths] [-- args]` | Run the tests with the routes wired. Arguments after `--` go to `dart test`. |

The entrypoint defaults to `bin/server.dart`, or the only file in `bin/`.

## How it works

The CLI reads the app with the Dart analyzer. It finds every `@Controller`
class in `lib/` and next to the entrypoint, then follows the `@Body()`
parameter types and the return types of its routes, through `Future`,
`Response<T>` and collections, to the classes that travel as JSON, and on
through their fields. It checks all of them and writes a route manifest, with
a typed JSON codec for each of those classes, plus an entry that installs it
into `.dart_tool/ratel/`. That entry is what actually runs, so the app's own
code never imports anything generated, and no build_runner, annotation or
extra dependency is needed. `ratel test` runs each test file through a wrapper
that installs the same manifest first, keeping the file's own tags and
settings; a test that calls a controller directly also runs with plain
`dart test`.

Mistakes surface as `file:line` diagnostics before anything starts, and a
JSON diagnostic names the path that reaches the problem, such as
`ItemsController.create -> Item.tags -> Tag.meta`. During `ratel dev` the
previous server keeps running until the errors are fixed, and the server stops
whenever the CLI does, even if the CLI is killed.

| Code | Meaning |
| --- | --- |
| `ratel_missing_controller` | A route annotation sits on a class without `@Controller`. |
| `ratel_private_class` | A controller, or a class that travels as JSON, is private. |
| `ratel_abstract_controller` | A `@Controller` class is abstract. |
| `ratel_generic_controller` | A `@Controller` class has type parameters. |
| `ratel_private_route_method` | A route method is private. |
| `ratel_static_route` | A route method is static. |
| `ratel_unbound_parameter` | A route parameter has no binding annotation. |
| `ratel_unknown_path_param` | A `@PathParam` names no `:segment` of its path. |
| `ratel_body_not_class` | A `@Body()` parameter is not a class, for example `int` or `Map`. |
| `ratel_dto_not_constructible` | A class decoded from JSON has no public unnamed constructor that sets its fields, or an optional parameter has no usable default. |
| `ratel_dto_abstract` | An abstract or sealed class without its own `toJson()` or `fromJson` travels as JSON. |
| `ratel_dto_unsupported_type` | A field has a type with no JSON form, such as a record, a function, a stream, or a generic class nested in itself with growing type arguments. |
| `ratel_missing_main` | The entrypoint declares no `main`. |
| `ratel_unsupported_main` | The entrypoint's `main` takes more than one parameter. |
| `ratel_no_controllers` | No `@Controller` class was found (a warning). |

Compile errors are reported with the analyzer's own codes.

The CLI lives in its own package so the tooling it needs never enters an
application's dependency graph. It is released in lockstep with `ratel`: use the
`ratel_cli` version that matches the `ratel` version your app resolves.

## Status

Early development (`2.0.0-dev`).
