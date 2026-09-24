class Injector {
  static Injector ambient = Injector.scoped();

  Injector.scoped();

  factory Injector() => ambient;

  final Map<Type, dynamic Function()> _factories = {};
  final Map<Type, dynamic> _instances = {};

  void put<T>(T Function() factory) {
    _factories[T] = factory;
    _instances.remove(T);
  }

  bool contains<T>() => _instances.containsKey(T) || _factories.containsKey(T);

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

  void clear() {
    _factories.clear();
    _instances.clear();
  }
}
