final class RatelSerializationException implements Exception {
  const RatelSerializationException(this.type);

  final Type type;

  @override
  String toString() =>
      'RatelSerializationException: no JSON encoder for $type. Annotate $type '
      'with @Json(), or give it a toJson() method.';
}
