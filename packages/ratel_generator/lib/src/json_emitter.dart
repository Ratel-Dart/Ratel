import 'package:analyzer/dart/element/element.dart';

import 'element_queries.dart';
import 'type_display.dart';

String emitToJson(ClassElement element) {
  final name = element.displayName;
  final entries = <String>[];
  for (final field in serializableFields(element)) {
    entries.add("'${field.displayName}': instance.${field.displayName},");
  }
  for (final getter in serializableGetters(element)) {
    entries.add("'${getter.displayName}': instance.${getter.displayName},");
  }
  final body = entries.map((e) => '      $e').join('\n');
  return 'Map<String, dynamic> \$${name}ToJson($name instance) =>\n'
      '    <String, dynamic>{\n$body\n    };';
}

String? emitFromJson(ClassElement element) {
  if (!canConstruct(element)) return null;
  final name = element.displayName;
  final lines = <String>['final instance = $name();'];
  for (final field in serializableFields(element)) {
    if (field.isFinal) continue;
    final type = nullableDisplay(field.type);
    lines.add(
      "if (json.containsKey('${field.displayName}')) "
      "instance.${field.displayName} = json['${field.displayName}'] as $type;",
    );
  }
  lines.add('return instance;');
  final body = lines.map((l) => '  $l').join('\n');
  return '$name \$${name}FromJson(Map<String, dynamic> json) {\n$body\n}';
}
