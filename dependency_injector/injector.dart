class Injector {
  static final Injector _instance = Injector._internal();
  factory Injector() => _instance;
  Injector._internal();

  final Map<Type, dynamic Function()> _factories = {};
  final Map<Type, dynamic> _instances = {};

  void Put<T>(T Function() factory) {
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
      throw Exception("Dependência do tipo $T não foi registrada.");
    }
  }
}
