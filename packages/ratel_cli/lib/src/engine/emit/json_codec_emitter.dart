import '../analysis/json_types.dart';
import '../model/construction_plan.dart';
import '../model/constructor_argument.dart';
import '../model/scanned_dto.dart';
import 'constant_emitter.dart';
import 'dart_literal.dart';
import 'import_allocator.dart';
import 'json_expression_emitter.dart';
import 'name_allocator.dart';
import 'type_emitter.dart';

final class JsonCodecEmitter {
  JsonCodecEmitter({required TypeEmitter types, required NameAllocator names})
      : _types = types,
        _names = names;

  final TypeEmitter _types;
  final NameAllocator _names;
  final Map<String, String> _encoders = {};
  final Map<String, String> _decoders = {};

  static const _r = ImportAllocator.runtimePrefix;

  String emit(List<ScannedDto> dtos, List<String> members) {
    for (final dto in dtos) {
      final key = JsonTypes.key(dto.type);
      final words = JsonTypes.words(dto.type);
      _encoders[key] = _names.allocate([...words, 'ToJson']);
      if (dto.decoding != null || dto.usesFromJson) {
        _decoders[key] = _names.allocate([...words, 'FromJson']);
      }
    }
    final definitions = StringBuffer();
    for (final dto in dtos) {
      final key = JsonTypes.key(dto.type);
      final type = _types.nonNullable(dto.type);
      final encoder = _encoders[key] ?? '';
      final decoder = _decoders[key];
      members.add(_encoder(dto, type, encoder));
      if (decoder != null) members.add(_decoder(dto, type, decoder));
      definitions
        ..writeln('      $_r.JsonCodecDefinition<$type>(')
        ..writeln('        encode: $encoder,');
      if (decoder != null) definitions.writeln('        decode: $decoder,');
      definitions.writeln('      ),');
    }
    return definitions.toString();
  }

  String _encoder(ScannedDto dto, String type, String name) {
    if (dto.usesToJson) {
      return '  static Object? $name($type value) => value.toJson();\n';
    }
    final expressions = _expressions();
    final entries = StringBuffer();
    for (final property in dto.properties) {
      final value = expressions.encode(property.type, 'value.${property.name}');
      entries.writeln('        ${DartLiteral.string(property.name)}: $value,');
    }
    return '  static Map<String, Object?> $name($type value) =>\n'
        '      <String, Object?>{\n'
        '$entries'
        '      };\n';
  }

  String _decoder(ScannedDto dto, String type, String name) {
    final signature = '  static $type $name(Map<String, Object?> json)';
    final plan = dto.decoding;
    if (plan == null) return '$signature =>\n      $type.fromJson(json);\n';
    final expressions = _expressions();
    if (plan.assignments.isEmpty) {
      return '$signature =>\n'
          '      $type(\n'
          '${_arguments(plan, expressions, '        ')}'
          '      );\n';
    }
    final arguments = _arguments(plan, expressions, '      ');
    final assignments = StringBuffer();
    for (final field in plan.assignments) {
      final key = DartLiteral.string(field.name);
      final value = expressions.decode(field.type, 'json[$key]', key);
      if (field.startsUnset) {
        assignments.writeln('    value.${field.name} = $value;');
        continue;
      }
      assignments
        ..writeln('    if (json.containsKey($key)) {')
        ..writeln('      value.${field.name} = $value;')
        ..writeln('    }');
    }
    return '$signature {\n'
        '    final value = $type(\n$arguments'
        '    );\n'
        '$assignments'
        '    return value;\n'
        '  }\n';
  }

  String _arguments(
    ConstructionPlan plan,
    JsonExpressionEmitter expressions,
    String indent,
  ) {
    final arguments = StringBuffer();
    for (final argument in plan.arguments) {
      final value = _argument(argument, expressions);
      final named = argument.isNamed ? '${argument.name}: ' : '';
      arguments.writeln('$indent$named$value,');
    }
    return arguments.toString();
  }

  String _argument(
    ConstructorArgument argument,
    JsonExpressionEmitter expressions,
  ) {
    final property = argument.property;
    final fallback = _fallback(argument);
    if (property == null) return fallback ?? 'null';
    final key = DartLiteral.string(property);
    final source = 'json[$key]';
    if (fallback == null) return expressions.decode(argument.type, source, key);
    if (!JsonTypes.isNullable(argument.type)) {
      return expressions.decodeOr(argument.type, source, key, fallback);
    }
    final value = expressions.decode(argument.type, source, key);
    return 'json.containsKey($key) ? $value : $fallback';
  }

  String? _fallback(ConstructorArgument argument) {
    final value = argument.defaultValue;
    if (value == null || value.isNull) return null;
    if (argument.isRequired && argument.property != null) return null;
    return ConstantEmitter.emit(value, _types.emit);
  }

  JsonExpressionEmitter _expressions() => JsonExpressionEmitter(
        types: _types,
        encoders: _encoders,
        decoders: _decoders,
      );
}
