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

The entrypoint defaults to `bin/server.dart`, or the only file in `bin/`.

## How it works

The CLI reads the app with the Dart analyzer. It finds every `@Controller` and
`@Json` class in `lib/` and next to the entrypoint, checks them, and writes a
route manifest plus an entry that installs it into `.dart_tool/ratel/`. That
entry is what actually runs, so the app's own code never imports anything
generated, and no build_runner or extra dependency is needed.

Mistakes surface as `file:line` diagnostics before anything starts: a route
annotation on a class without `@Controller`, a private controller, a `@Body`
type that is not `@Json`, or code that does not compile. During `ratel dev`
the previous server keeps running until the errors are fixed, and the server
stops whenever the CLI does, even if the CLI is killed.

The CLI lives in its own package so the tooling it needs never enters an
application's dependency graph. It is released in lockstep with `ratel`: use the
`ratel_cli` version that matches the `ratel` version your app resolves.

## Status

Early development (`2.0.0-dev`).
