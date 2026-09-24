class RatelControllers {
  RatelControllers._();

  static final Map<Type, Function> _overrides = {};
  static final Map<Type, Function> _defaults = {};

  static void register<T>(T Function() factory) => _overrides[T] = factory;

  static void registerDefault<T>(T Function() factory) =>
      _defaults[T] = factory;

  static T create<T>() {
    final factory = _overrides[T] ?? _defaults[T];
    if (factory == null) {
      throw StateError(
        'No factory registered for controller $T. It has no no-argument '
        'constructor, so register one with RatelControllers.register<$T>(), '
        'typically from Bindings.dependencies().',
      );
    }
    return (factory as T Function())();
  }

  static void reset() {
    _overrides.clear();
    _defaults.clear();
  }
}
