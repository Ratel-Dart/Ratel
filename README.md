<h1 align="center">Ratel Generator</h1>

`build_runner` code generators for the [Ratel](https://github.com/Ratel-Dart/Ratel)
framework and [ratel_orm](https://github.com/Ratel-Dart/ratel_orm). They replace
Ratel's runtime `dart:mirrors` reflection with generated code, so Ratel apps
compile ahead-of-time (`dart compile exe`).

Generated per annotation:

- `@Json` → `toJson` / `fromJson`
- controllers (`RatelHandler` subclasses) → route tables with typed parameter
  binding
- `@Column` → entity row mappers for the ORM repository

## Usage

Add as a dev dependency alongside `build_runner`, add `part '<file>.g.dart';`
to files with the annotations above, then run:

```sh
dart run build_runner build
```

## Status

Early development (`0.1.0-dev`).
