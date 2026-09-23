## 0.1.0-dev.1

- Initial generators: `@Json` serialization, controller route tables and
  `@Column` row mappers.
- Migrated to the current analyzer element model. The package now requires
  `analyzer ^14.0.0`, `build ^4.0.0` and `source_gen ^4.0.0`.
- `@Column` is matched at `package:ratel_orm/annotations.dart` instead of
  reaching into `lib/src/`.
- Added a test suite over `testBuilder`, covering JSON serialization, route
  tables, parameter binding, row mappers, cross-library `@Body` resolution and
  controller factory registration.
