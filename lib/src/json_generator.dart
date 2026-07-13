import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

const _jsonChecker =
    TypeChecker.fromUrl('package:ratel/annotations/annotations.dart#Json');

/// Emits `_$<Name>ToJson` (and `_$<Name>FromJson` when the class has a
/// no-argument constructor) for every `@Json`-annotated class, so request and
/// response (de)serialization no longer needs `dart:mirrors`.
class JsonGenerator extends Generator {
  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final output = StringBuffer();
    for (final element in library.classes) {
      if (!_jsonChecker.hasAnnotationOfExact(element)) continue;
      output
        ..writeln(_toJson(element))
        ..writeln();
      final fromJson = _fromJson(element);
      if (fromJson != null) output.writeln(fromJson);
    }
    final result = output.toString().trim();
    return result.isEmpty ? null : result;
  }

  Iterable<FieldElement> _serializableFields(ClassElement element) =>
      element.fields.where(
        (f) => !f.isStatic && !f.isPrivate && !f.isSynthetic,
      );

  String _toJson(ClassElement element) {
    final name = element.name;
    final entries = <String>[];
    for (final field in _serializableFields(element)) {
      entries.add("'${field.name}': instance.${field.name},");
    }
    for (final accessor in element.accessors) {
      if (!accessor.isGetter ||
          accessor.isStatic ||
          accessor.isPrivate ||
          accessor.isSynthetic) {
        continue;
      }
      entries.add("'${accessor.name}': instance.${accessor.name},");
    }
    final body = entries.map((e) => '      $e').join('\n');
    return 'Map<String, dynamic> _\$${name}ToJson($name instance) =>\n'
        '    <String, dynamic>{\n$body\n    };';
  }

  String? _fromJson(ClassElement element) {
    final canConstruct = element.constructors.any(
      (c) =>
          c.name.isEmpty && c.parameters.every((p) => p.isOptional) ||
          c.name.isEmpty && c.parameters.isEmpty,
    );
    if (!canConstruct) return null;

    final name = element.name;
    final lines = <String>['final instance = $name();'];
    for (final field in _serializableFields(element)) {
      if (field.isFinal) continue;
      final type = field.type.getDisplayString(withNullability: true);
      lines.add(
        "if (json.containsKey('${field.name}')) "
        "instance.${field.name} = json['${field.name}'] as $type;",
      );
    }
    lines.add('return instance;');
    final body = lines.map((l) => '  $l').join('\n');
    return '$name _\$${name}FromJson(Map<String, dynamic> json) {\n$body\n}';
  }
}
