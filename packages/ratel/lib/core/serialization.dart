class RatelJson {
  RatelJson._();

  static final Map<Type, Object? Function(Object)> _encoders = {};

  static void register<T>(Map<String, dynamic> Function(T) toJson) {
    _encoders[T] = (object) => toJson(object as T);
  }

  static Object? Function(Object)? encoderFor(Type type) => _encoders[type];

  static void reset() => _encoders.clear();
}
