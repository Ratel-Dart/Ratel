/// A service locator holding lazily built singletons.
///
/// Register a factory with [put]; the first [get] for a type builds and caches
/// a single instance that subsequent calls reuse.
///
/// `Injector()` returns the ambient injector, which is what an application and
/// its `Bindings` use. A test, or a second server in the same isolate, builds
/// an isolated one with [Injector.scoped] and installs it as [ambient].
class Injector {
  /// The injector `Injector()` hands out. Replace it to scope registrations to
  /// a test or to one server in an isolate that runs several.
  static Injector ambient = Injector.scoped();

  /// Creates an injector with no registrations of its own.
  Injector.scoped();

  /// Returns the ambient injector.
  factory Injector() => ambient;

  final Map<Type, dynamic Function()> _factories = {};
  final Map<Type, dynamic> _instances = {};

  /// Registers [factory] as the way to build [T].
  void put<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Returns the singleton [T], building it on first use.
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

  /// Forgets every registration and cached instance.
  void clear() {
    _factories.clear();
    _instances.clear();
  }
}
