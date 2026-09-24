final class JsonCodecDefinition<T extends Object> {
  const JsonCodecDefinition({required this.encode, this.decode});

  final Object? Function(T value) encode;
  final T Function(Map<String, Object?> json)? decode;

  Type get type => T;

  Object? encodeObject(Object value) => encode(value as T);
}
