import 'package:analyzer/dart/element/element.dart';

import 'annotation_checkers.dart';
import 'constant_values.dart';
import 'type_display.dart';

String emitFromRow(ClassElement element, List<FieldElement> columns) {
  final name = element.displayName;
  final lines = <String>['final entity = $name();'];
  for (final field in columns) {
    final annotation = columnChecker.firstAnnotationOf(field);
    final column =
        (readString(annotation, 'name') ?? field.displayName).toLowerCase();
    final type = nullableDisplay(field.type);
    lines.add(
      "if (row.containsKey('$column')) "
      "entity.${field.displayName} = row['$column'] as $type;",
    );
  }
  lines.add('return entity;');
  final body = lines.map((l) => '  $l').join('\n');
  return '$name \$${name}FromRow(Map<String, Object?> row) {\n$body\n}';
}
