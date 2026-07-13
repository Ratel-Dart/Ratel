import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

const _columnChecker =
    TypeChecker.fromUrl('package:ratel_orm/src/annotations.dart#Column');

/// Emits `_$<Name>FromRow` for every class with `@Column` fields, so the ORM
/// repository can map query rows onto entities without `dart:mirrors`.
class RowMapperGenerator extends Generator {
  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final output = StringBuffer();
    for (final element in library.classes) {
      final columns = element.fields
          .where(
            (f) =>
                !f.isStatic &&
                !f.isSynthetic &&
                _columnChecker.hasAnnotationOf(f),
          )
          .toList();
      if (columns.isEmpty) continue;
      output.writeln(_fromRow(element, columns));
    }
    final result = output.toString().trim();
    return result.isEmpty ? null : result;
  }

  String _fromRow(ClassElement element, List<FieldElement> columns) {
    final name = element.name;
    final lines = <String>['final entity = $name();'];
    for (final field in columns) {
      final annotation = _columnChecker.firstAnnotationOf(field);
      final column =
          (_readString(annotation, 'name') ?? field.name).toLowerCase();
      final type = field.type.getDisplayString(withNullability: true);
      lines.add(
        "if (row.containsKey('$column')) "
        "entity.${field.name} = row['$column'] as $type;",
      );
    }
    lines.add('return entity;');
    final body = lines.map((l) => '  $l').join('\n');
    return '$name _\$${name}FromRow(Map<String, Object?> row) {\n$body\n}';
  }
}

String? _readString(DartObject? object, String field) {
  if (object == null) return null;
  final reader = ConstantReader(object).read(field);
  return reader.isString ? reader.stringValue : null;
}
