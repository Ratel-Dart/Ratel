/// Registry of generated row mappers for `@Column` entities.
///
/// Generated code registers one mapper per entity from `$registerRatel()`;
/// [RatelRepository] looks its own up by type, so a repository needs no mapper
/// wiring of its own. Applications do not call this directly.
class RatelRowMappers {
  RatelRowMappers._();

  static final Map<Type, Function> _mappers = {};

  /// Registers [fromRow] as the mapper for entity [T].
  static void register<T>(T Function(Map<String, Object?> row) fromRow) {
    _mappers[T] = fromRow;
  }

  /// The mapper registered for [T].
  ///
  /// Throws [StateError] when [T] has none — typically because the entity has
  /// no `@Column` fields, or because code generation has not run.
  static T Function(Map<String, Object?> row) of<T>() {
    final mapper = _mappers[T];
    if (mapper == null) {
      throw StateError(
        'No row mapper registered for $T. Annotate its fields with @Column, or '
        'pass a mapper to the repository constructor.',
      );
    }
    return mapper as T Function(Map<String, Object?> row);
  }

  /// Removes every registered mapper. Intended for tests.
  static void reset() => _mappers.clear();
}
