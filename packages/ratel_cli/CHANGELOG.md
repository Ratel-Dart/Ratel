## 2.0.0-dev.8 (unreleased)

- The CLI generates the entity mapping for `ratel_orm`. It finds the `@Entity`
  classes in `lib/` and next to the entrypoint, checks them against the ORM's
  rules and writes `ratel_entity_manifest.dart`, with a typed `fromRow` and
  `toRow` for each entity. The entry and every `ratel test` wrapper install it
  with `RatelOrmRuntime.install` before any code runs. When the project uses
  `ratel` too, the route manifest's `isolateSetup` installs it in every
  `RatelCluster.run` isolate.
- New diagnostics for entities and repositories: `ratel_entity_abstract`,
  `ratel_entity_generic`, `ratel_entity_no_id`, `ratel_entity_multiple_ids`,
  `ratel_entity_not_constructible`, `ratel_entity_unsettable_field`,
  `ratel_entity_unsupported_type`, `ratel_entity_private_field` (a warning,
  and an error on a private field marked `@Column()` or `@Id()`),
  `ratel_entity_empty_name`, `ratel_entity_column_clash`,
  `ratel_entity_table_clash` (a warning), `ratel_orm_annotation_misplaced`,
  `ratel_repository_not_entity` and `ratel_repository_id_mismatch`. Table and
  column names are worked out the way `ratel_orm` does at run time, so an
  empty name or two fields on one column fail before the app starts instead of
  in `RatelOrmRuntime.install`. A `RatelRepository` with one type argument
  gets a hint that it now takes `<T, ID>`.
- Projects that depend on `ratel_orm` without `ratel` work with `ratel dev`,
  `ratel build` and `ratel test`; the CLI scans them for entities only. It
  checks the `ratel_orm` runtime contract next to the `ratel` one and prints
  both with `--version`. A project that depends on neither is told which one
  to add.
- `ratel dev` lets a script that finishes exit, reports
  `<entrypoint> exited with code N` and runs it again on the next change. The
  watchdog that stops the app together with the CLI now runs in its own
  isolate. A change to `pubspec.yaml` makes it check the runtimes again, so
  adding `ratel_orm` takes effect without a restart.
- JSON codecs come from the route signatures instead of `@Json`. The engine
  starts from each `@Body()` parameter type and each route's return type,
  looking through `Future`, `FutureOr`, `Response<T>`, `List`, `Set`,
  `Iterable` and `Map<String, T>`, and follows the fields of every class it
  reaches, classes from other packages included. Each generic instantiation,
  such as `Page<Item>`, gets its own codec.
- Generated codecs are typed. Encoders call the nested encoders directly and
  convert enums, `DateTime`, `Uri` and `BigInt`. Decoders call the public
  unnamed constructor, matching `this.x`, `super.x`, declaring and plain
  parameters to fields, copy default values into the generated code, assign
  the mutable fields the constructor leaves out, and read every value through
  `JsonValues`, so a bad body answers 400 naming the field. Fields declared by
  a primary constructor are now included. A class that declares `toJson()` or
  a `fromJson` constructor is converted through them, and a `late` field
  without an initializer is always assigned.
- New diagnostics name the path from the route to the problem, such as
  `ItemsController.create -> Item.tags -> Tag.meta`: `ratel_body_not_class`,
  `ratel_dto_not_constructible`, `ratel_dto_abstract` and
  `ratel_dto_unsupported_type`. A leftover `@Json()` gets a hint that the
  annotation was removed.
- Generated string literals escape backslashes. A route path or JSON key
  holding a backslash turned into a different string, or into code that did
  not compile.
- `ratel create` writes an immutable `Greeting` DTO with no annotation to
  `lib/dtos/`, and the scaffold's route returns `Future<Greeting>`.
- The engine resolves @Protected and @Public on @Socket methods with the same
  rule as routes and writes the result into the `SocketDefinition`, so protected
  sockets are enforced.
- The engine now rejects route methods it would call wrongly. A route parameter
  with no binding annotation reports `ratel_unbound_parameter` and lists the
  annotations it could use; before, it was given `null`. A static route method
  reports `ratel_static_route`; before, it was skipped without a message. A
  `@PathParam` whose name is not a `:segment` of its route path reports
  `ratel_unknown_path_param`.
- The `ratel` executable moved here from the `ratel` package, so an
  application's dependencies no longer carry the CLI. Install it with
  `dart pub global activate ratel_cli`. It is released in lockstep with
  `ratel`.
- `ratel dev`, `ratel build` and `ratel create` run on the engine, built on
  `package:analyzer` with no build_runner. It finds `@Controller` classes in
  `lib/` and next to the entrypoint, even when nothing imports them.
  It reports misplaced annotations and compile errors as `file:line`
  diagnostics. It writes a const route manifest plus an entry that installs it
  into `.dart_tool/ratel/<mode>/`, and nothing into the project.
- `ratel dev` re-analyzes only what changed and restarts the server. It keeps
  the previous server running while the code does not compile. It stops the
  server with the CLI, even when the CLI is killed outright. Arguments after
  `--` are forwarded to `main`.
- `ratel build` compiles to `build/<entrypoint>`, or uses `dart build cli`
  when a dependency ships build hooks.
- `ratel test` runs each test file through a wrapper in `.dart_tool/ratel/test/`
  that installs the route manifest first, so HTTP tests reach the app's routes.
  The wrapper keeps the file's library annotations (`@Tags`, `@Timeout`, and so
  on), and arguments after `--` go to `dart test`.
- `ratel create` scaffolds a pubspec without code generation dependencies,
  the DTO and the controller in separate files, a sample HTTP test, and no
  comments anywhere.
- Before it generates anything, the CLI checks that it matches the runtime
  contract of the `ratel` the app resolves.
