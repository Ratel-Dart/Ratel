<h1 align="center">Ratel ORM</h1>

Database ORM layer for the [Ratel](https://github.com/Ratel-Dart/Ratel) framework.

`ratel` (the core framework) owns the database **contract** — the `RatelDriver`
interface, `QueryResult`, transactions, typed exceptions and a raw-SQL facade —
and stays database-agnostic. `ratel_orm` builds the higher-level data layer on
top of that contract:

- `RatelRepository<T>` with `@Column`-based row mapping
- a SQL dialect layer
- database drivers, bundled as sub-libraries (the Postgres driver lives at
  `package:ratel_orm/postgres.dart`)

## Status

Early development (`0.1.0-dev`). The API may change before `1.0`.
