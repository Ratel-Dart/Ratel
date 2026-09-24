## 2.0.0-dev.8 (unreleased)

- The `ratel` executable moved here from the `ratel` package, so an
  application's dependencies no longer carry the CLI. Install it with
  `dart pub global activate ratel_cli`. It is released in lockstep with
  `ratel`.
- The code generation engine, built on `package:analyzer` with no
  build_runner. It finds `@Controller` classes in `lib/` and next to the
  entrypoint (including files nothing imports), reports misplaced annotations
  and compile errors as `file:line` diagnostics, and writes a const route
  manifest plus an entry that installs it into `.dart_tool/ratel/<mode>/`.
  Not yet wired to any command.
