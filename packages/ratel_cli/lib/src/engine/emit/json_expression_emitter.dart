import 'package:analyzer/dart/element/type.dart';

import '../analysis/json_types.dart';
import '../model/json_kind.dart';
import 'import_allocator.dart';
import 'type_emitter.dart';

final class JsonExpressionEmitter {
  JsonExpressionEmitter({
    required TypeEmitter types,
    required Map<String, String> encoders,
    required Map<String, String> decoders,
  })  : _types = types,
        _encoders = encoders,
        _decoders = decoders;

  final TypeEmitter _types;
  final Map<String, String> _encoders;
  final Map<String, String> _decoders;
  int _next = 0;

  static const _r = ImportAllocator.runtimePrefix;

  static const _readers = {
    JsonKind.integer: 'integer',
    JsonKind.real: 'real',
    JsonKind.number: 'number',
    JsonKind.string: 'string',
    JsonKind.boolean: 'boolean',
    JsonKind.dateTime: 'dateTime',
    JsonKind.uri: 'uri',
    JsonKind.bigInt: 'bigInt',
    JsonKind.opaque: 'present',
  };

  static const _blankable = {
    JsonKind.integer,
    JsonKind.real,
    JsonKind.number,
    JsonKind.boolean,
    JsonKind.dateTime,
    JsonKind.bigInt,
    JsonKind.enumeration,
  };

  String encode(DartType type, String source) {
    if (JsonTypes.passesThrough(type)) return source;
    if (!JsonTypes.isNullable(type)) return _encodeValue(type, source);
    final value = _fresh('v');
    return 'switch ($source) { null => null, final $value => '
        '${_encodeValue(type, value)} }';
  }

  String decode(DartType type, String source, String field) {
    if (!JsonTypes.isNullable(type)) return _decodeValue(type, source, field);
    if (JsonTypes.kind(type) == JsonKind.opaque) return source;
    return decodeOr(type, source, field, 'null');
  }

  String decodeOr(
    DartType type,
    String source,
    String field,
    String fallback,
  ) {
    final given = _blankable.contains(JsonTypes.kind(type))
        ? '$_r.JsonValues.nonBlank($source)'
        : source;
    final value = _fresh('v');
    return 'switch ($given) { null => $fallback, final $value => '
        '${_decodeValue(type, value, field)} }';
  }

  String _encodeValue(DartType type, String source) {
    final kind = JsonTypes.kind(type);
    switch (kind) {
      case JsonKind.dateTime:
        return '$source.toIso8601String()';
      case JsonKind.uri:
      case JsonKind.bigInt:
        return '$source.toString()';
      case JsonKind.enumeration:
        return _declaresName(type) ? 'EnumName($source).name' : '$source.name';
      case JsonKind.dto:
        return '${_codec(_encoders, type)}($source)';
      case JsonKind.list:
      case JsonKind.set:
      case JsonKind.iterable:
        final element = _fresh('e');
        return '[for (final $element in $source) '
            '${encode(JsonTypes.elementOf(type), element)}]';
      case JsonKind.map:
        final key = _fresh('k');
        final value = _fresh('v');
        return '{for (final MapEntry(key: $key, value: $value) in '
            '$source.entries) $key: ${encode(JsonTypes.valueOf(type), value)}}';
      case JsonKind.integer:
      case JsonKind.real:
      case JsonKind.number:
      case JsonKind.string:
      case JsonKind.boolean:
      case JsonKind.opaque:
        return source;
      case JsonKind.unsupported:
        throw StateError('No JSON encoding for ${type.getDisplayString()}.');
    }
  }

  String _decodeValue(DartType type, String source, String field) {
    final kind = JsonTypes.kind(type);
    final reader = _readers[kind];
    if (reader != null) return '$_r.JsonValues.$reader($source, $field)';
    switch (kind) {
      case JsonKind.enumeration:
        return '$_r.JsonValues.enumeration($source, '
            '${_types.nonNullable(type)}.values, $field)';
      case JsonKind.dto:
        return '${_codec(_decoders, type)}'
            '($_r.JsonValues.object($source, $field))';
      case JsonKind.list:
      case JsonKind.set:
      case JsonKind.iterable:
        final list = '$_r.JsonValues.list($source, $field)';
        final elementType = JsonTypes.elementOf(type);
        if (_isLoose(elementType)) {
          return kind == JsonKind.set ? '$list.toSet()' : list;
        }
        final element = _fresh('e');
        final item = decode(elementType, element, field);
        return kind == JsonKind.set
            ? '{for (final $element in $list) $item}'
            : '[for (final $element in $list) $item]';
      case JsonKind.map:
        final object = '$_r.JsonValues.object($source, $field)';
        final valueType = JsonTypes.valueOf(type);
        if (_isLoose(valueType)) return object;
        final key = _fresh('k');
        final value = _fresh('v');
        return '{for (final MapEntry(key: $key, value: $value) in '
            '$object.entries) $key: ${decode(valueType, value, field)}}';
      default:
        throw StateError('No JSON decoding for ${type.getDisplayString()}.');
    }
  }

  static bool _declaresName(DartType type) {
    if (type is! InterfaceType) return false;
    final getter = type.lookUpGetter('name', type.element.library);
    return getter != null && !getter.library.uri.isScheme('dart');
  }

  bool _isLoose(DartType type) =>
      JsonTypes.kind(type) == JsonKind.opaque && JsonTypes.isNullable(type);

  String _codec(Map<String, String> names, DartType type) {
    final key = JsonTypes.key(JsonTypes.nonNullable(type as InterfaceType));
    final name = names[key];
    if (name == null) {
      throw StateError('No codec was planned for ${type.getDisplayString()}.');
    }
    return name;
  }

  String _fresh(String prefix) => '$prefix${_next++}';
}
