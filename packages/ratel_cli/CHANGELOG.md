## 2.0.0-dev.8 (unreleased)

- The `ratel` executable moved here from the `ratel` package, so an
  application's dependencies no longer carry the CLI. Install it with
  `dart pub global activate ratel_cli`. It is released in lockstep with
  `ratel`.
- `ratel dev`, `ratel build` and `ratel create` run on the engine, built on
  `package:analyzer` with no build_runner. It finds `@Controller` and `@Json`
  classes in `lib/` and next to the entrypoint, even when nothing imports them.
  It reports misplaced annotations and compile errors as `file:line`
  diagnostics. It writes a const route manifest plus an entry that installs it
  into `.dart_tool/ratel/<mode>/`, and nothing into the project.
- `ratel dev` re-analyzes only what changed and restarts the server. It keeps
  the previous server running while the code does not compile. It stops the
  server with the CLI, even when the CLI is killed outright. Arguments after
  `--` are forwarded to `main`.
- `ratel build` compiles to `build/<entrypoint>`, or uses `dart build cli`
  when a dependency ships build hooks.
- `ratel create` scaffolds a pubspec without code generation dependencies,
  the model and the controller in separate files, and no comments anywhere.
- Before it generates anything, the CLI checks that it matches the runtime
  contract of the `ratel` the app resolves.
