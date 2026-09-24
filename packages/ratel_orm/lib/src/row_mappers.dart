class RatelRowMappers {
  RatelRowMappers._();

  static final Map<Type, Function> _mappers = {};

  static void register<T>(T Function(Map<String, Object?> row) fromRow) {
    _mappers[T] = fromRow;
  }

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

  static void reset() => _mappers.clear();
}
