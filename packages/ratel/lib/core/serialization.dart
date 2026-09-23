/// Registry of JSON encoders for `@Json` classes.
///
/// Generated code registers one encoder per annotated class from
/// `$registerRatel()`; [Response] looks them up when serializing a payload.
/// Applications do not call this directly.
class RatelJson {
  RatelJson._();

  static final Map<Type, Object? Function(Object)> _encoders = {};

  /// Registers [toJson] as the encoder for [T].
  static void register<T>(Map<String, dynamic> Function(T) toJson) {
    _encoders[T] = (object) => toJson(object as T);
  }

  /// The encoder registered for [type], or `null` when it has none.
  static Object? Function(Object)? encoderFor(Type type) => _encoders[type];

  /// Removes every registered encoder. Intended for tests.
  static void reset() => _encoders.clear();
}
