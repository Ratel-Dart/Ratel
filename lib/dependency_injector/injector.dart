/// A minimal process-wide service locator.
///
/// Register a factory with [put]; the first [get] for a type builds and caches a
/// single instance (lazy singleton) that subsequent calls reuse.
class Injector {
  static final Injector _instance = Injector._internal();
  factory Injector() => _instance;
  Injector._internal();

  final Map<Type, dynamic Function()> _factories = {};
  final Map<Type, dynamic> _instances = {};

  void put<T>(T Function() factory) {
    _factories[T] = factory;
  }

  T get<T>() {
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    } else if (_factories.containsKey(T)) {
      T instance = _factories[T]!() as T;
      _instances[T] = instance;
      return instance;
    } else {
      throw Exception('No dependency of type $T has been registered.');
    }
  }
}
