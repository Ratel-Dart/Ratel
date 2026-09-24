<h1 align="center">Ratel CLI</h1>

The `ratel` command for [Ratel](https://github.com/Ratel-Dart/Ratel)
applications. Install it once:

```sh
dart pub global activate ratel_cli
```

| Command | What it does |
| --- | --- |
| `ratel create <name>` | Scaffold a new application. |
| `ratel dev [entrypoint]` | Run the app and restart it on every change. |
| `ratel build [entrypoint]` | Compile a native binary to `build/`. |

The CLI lives in its own package so the tooling it needs never enters an
application's dependency graph. It is released in lockstep with `ratel`: use the
`ratel_cli` version that matches the `ratel` version your app resolves.

## Status

Early development (`2.0.0-dev`).
