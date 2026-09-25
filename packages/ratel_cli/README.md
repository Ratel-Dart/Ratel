<h1 align="center">Ratel CLI</h1>

The `ratel` command for [Ratel](https://github.com/Ratel-Dart/Ratel)
applications and for projects that store `@Entity` classes with
[ratel_orm](https://github.com/Ratel-Dart/ratel_orm). Install it once:

```sh
dart pub global activate ratel_cli
```

| Command | What it does |
| --- | --- |
| `ratel create <name>` | Scaffold a new application. |
| `ratel dev [entrypoint] [-- args]` | Run the app and restart it on every change. Arguments after `--` reach the app's `main`. |
| `ratel build [entrypoint]` | Compile a native binary into `build/`. |
| `ratel test [paths] [-- args]` | Run the tests with the routes and entities wired. Arguments after `--` go to `dart test`. |

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

## Entities

When the project depends on `ratel_orm`, the CLI also finds every `@Entity`
class in `lib/` and next to the entrypoint and writes an entity manifest,
`.dart_tool/ratel/<mode>/ratel_entity_manifest.dart`. It holds one
`EntityDefinition` per entity, with the table and column names and a typed
`fromRow` and `toRow` that construct the entity and read it back. The entry
installs it with `RatelOrmRuntime.install` before `main` runs, and each
`ratel test` wrapper does the same, so a `RatelRepository<T, ID>` maps its rows
without reflection or hand-written mappers.

The CLI applies the ORM's rules and reports every break of them:

- Every public instance field is a column unless it is marked `@Transient()`,
  inherited fields and primary-constructor fields included. Getters never
  are.
- An entity has exactly one `@Id()` field.
- A column is an `int`, `double`, `num`, `String`, `bool`, `DateTime`,
  `Uint8List`, `List<int>` or an enum, each possibly nullable. `toRow` turns a
  `List<int>` into a `Uint8List`, so every driver stores it as bytes, keeping
  the low eight bits of each element.
- A column is named by `@Column(name:)` or else by the snake_case of its field
  (`createdAt` is `created_at`), and a table by `@Entity(table:)` or else by
  the snake_case of the class, as `ratel_orm` names them at run time. No name
  is empty, and no two columns of an entity share a name. Two entities that
  map to the same table get a warning.
- A private field is not stored, so `@Column()` or `@Id()` on one is an error.
  A redundant `@Transient()` on a getter, a setter or a static member of an
  entity is accepted.
- The row is turned back into an entity through its public unnamed
  constructor. Every column must be a parameter of it or a mutable field.
- A `RatelRepository<T, ID>` stores an `@Entity` of this project, and `ID` is
  the type of its `@Id()` field.

With `ratel` in the project too, the route manifest lists a hook in
`isolateSetup` that installs the entity manifest, so every isolate that
`RatelCluster.run` starts maps entities as well. `ratel` itself knows nothing
about the ORM.

Plain `dart run`, `dart compile exe` and `dart test` skip generation, so the
first repository they construct fails with a message that points back to the
CLI.

## Projects without ratel

A project that depends on `ratel_orm` and not on `ratel`, such as a CLI tool, a
worker or a migration script, uses the same commands. `ratel dev` runs the
entrypoint again after every change, and when the script finishes, it waits
for the next one. `ratel build` compiles it and `ratel test` runs its tests
with the entity manifest installed. The CLI looks for no controllers there
and writes no route manifest.

A project with neither package gets:
`This project depends on neither ratel nor ratel_orm. Run: dart pub add ratel
(HTTP) or dart pub add ratel_orm (database).`

## Runtime contracts

Before it generates anything, the CLI reads two constants through the
analyzer and stops with a message when they are not the ones it generates
for:

| Package | Constant | Contract |
| --- | --- | --- |
| `ratel` | `RatelRuntime.contract` in `package:ratel/runtime.dart` | 1 |
| `ratel_orm` | `RatelOrmRuntime.contract` in `package:ratel_orm/runtime.dart` | 1 |

`ratel --version` prints both. A `ratel_orm` that has no
`package:ratel_orm/runtime.dart` predates generated mappers: next to `ratel`
the CLI generates no entities for it, and on its own it asks for
`dart pub upgrade ratel_orm`. The CLI never depends on either package; it
recognises their annotations and classes by package and name.

## Diagnostics

| Code | Meaning |
| --- | --- |
| `ratel_missing_controller` | A route annotation sits on a class without `@Controller`. |
| `ratel_private_class` | A controller, a class that travels as JSON, or an entity is private. |
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
| `ratel_entity_abstract` | An `@Entity` class is abstract or sealed. |
| `ratel_entity_generic` | An `@Entity` class has type parameters. |
| `ratel_entity_no_id` | An entity has no `@Id()` field. |
| `ratel_entity_multiple_ids` | An entity marks more than one field with `@Id()`. |
| `ratel_entity_not_constructible` | An entity has no public unnamed constructor that takes its columns, or a parameter it skips has a default that cannot be copied. |
| `ratel_entity_unsettable_field` | A final column is not a constructor parameter. Add it to the constructor, or mark it `@Transient()`. |
| `ratel_entity_unsupported_type` | A column has a type no column can hold. Change the type, or mark the field `@Transient()`. |
| `ratel_entity_private_field` | A private field of an entity is not stored (a warning), or a private field is marked `@Column()` or `@Id()` (an error). |
| `ratel_entity_empty_name` | `@Entity(table: '')` or `@Column(name: '')`. |
| `ratel_entity_column_clash` | Two fields of an entity map to the same column name. |
| `ratel_entity_table_clash` | Two entities map to the same table (a warning). |
| `ratel_orm_annotation_misplaced` | `@Column`, `@Id` or `@Transient` outside an entity's fields, `@Column` or `@Id` on a getter, setter or static field, `@Id` together with `@Transient`, or `@Entity` on something that is not a class. |
| `ratel_repository_not_entity` | A `RatelRepository<T, ID>` stores a `T` that is not an `@Entity` of this project. |
| `ratel_repository_id_mismatch` | The `ID` of a `RatelRepository<T, ID>` is not the type of the entity's `@Id()` field. |
| `ratel_missing_main` | The entrypoint declares no `main`. |
| `ratel_unsupported_main` | The entrypoint's `main` takes more than one parameter. |
| `ratel_no_controllers` | A project with `ratel` has no `@Controller` class (a warning). |

Compile errors are reported with the analyzer's own codes. A `RatelRepository`
with a single type argument, from before entities were mapped, gets a hint
that it now takes `<T, ID>`.

The CLI lives in its own package so the tooling it needs never enters an
application's dependency graph. It is released in lockstep with `ratel`: use the
`ratel_cli` version that matches the `ratel` version your app resolves.

## Status

Early development (`2.0.0-dev`).
