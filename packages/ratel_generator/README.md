<h1 align="center">Ratel Generator</h1>

`build_runner` code generator for the [Ratel](https://github.com/Ratel-Dart/Ratel)
framework. It replaces Ratel's runtime `dart:mirrors` reflection with generated
code, so Ratel apps compile ahead-of-time (`dart compile exe`).

For every source file holding annotated classes it emits a standalone
`<file>.ratel.dart` library — not a `part`, so **applications never declare a
`part` directive**:

| Annotation | Generated |
|---|---|
| `@Json` | `$XToJson`, plus `$XFromJson` when the class has an unnamed constructor with no required parameters |
| controller (a `RatelHandler` subclass) | `$XRoutes(factory)` — a route table with typed parameter binding |

Each generated library also exposes a `$registerRatel()` that wires those into
the runtime registries. Emitting a library rather than a part is what lets a
`@Body` model be resolved across file boundaries.

## Usage

You normally do not set this up by hand: `ratel create` scaffolds it, and
`ratel dev` / `ratel build` run generation and the bootstrap that calls every
`$registerRatel()` for you.

To wire it manually, add it as a dev dependency alongside `build_runner` and
run:

```sh
dart run build_runner build --delete-conflicting-outputs
```

The builder is `auto_apply: dependents`, so no `build.yaml` is needed. Generated
files sit next to their sources and belong in `.gitignore`:

```
*.ratel.dart
```

## Status

Early development (`0.1.0-dev`).
