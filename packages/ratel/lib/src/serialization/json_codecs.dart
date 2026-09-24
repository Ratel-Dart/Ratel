import '../runtime/json_codec_definition.dart';

final class JsonCodecs {
  JsonCodecs(Iterable<JsonCodecDefinition<Object>> definitions)
      : _byType = _index(definitions);

  const JsonCodecs.empty() : _byType = const {};

  final Map<Type, JsonCodecDefinition<Object>> _byType;

  JsonCodecDefinition<Object>? forType(Type type) => _byType[type];

  static Map<Type, JsonCodecDefinition<Object>> _index(
    Iterable<JsonCodecDefinition<Object>> definitions,
  ) {
    final byType = <Type, JsonCodecDefinition<Object>>{};
    for (final definition in definitions) {
      if (byType.containsKey(definition.type)) {
        throw StateError(
          'Two JSON codecs are registered for ${definition.type}.',
        );
      }
      byType[definition.type] = definition;
    }
    return Map.unmodifiable(byType);
  }
}
