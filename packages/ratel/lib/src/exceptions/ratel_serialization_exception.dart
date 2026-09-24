final class RatelSerializationException implements Exception {
  const RatelSerializationException(this.type);

  final Type type;

  String get message => 'No JSON encoder for $type. Ratel generates encoders '
      'for the types that route signatures declare: return $type or '
      'Response<$type> from a route, or reach it through a field of such a '
      'type. A raw Response hides its payload type, and the encoder is chosen '
      'by the exact runtime class.';

  @override
  String toString() => 'RatelSerializationException: $message';
}
