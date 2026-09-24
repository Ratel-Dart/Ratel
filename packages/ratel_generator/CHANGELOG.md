## 0.1.0-dev.1

- Initial generators: `@Json` serialization and controller route tables.
- Migrated to the current analyzer element model. The package now requires
  `analyzer ^14.0.0`, `build ^4.0.0` and `source_gen ^4.0.0`.
- Added a test suite over `testBuilder`, covering JSON serialization, route
  tables, parameter binding, cross-library `@Body` resolution and controller
  factory registration.
- The generator no longer knows `ratel_orm`: `@Column` row mappers are gone,
  because `ratel_orm` now maps rows explicitly through `fromRow`.
