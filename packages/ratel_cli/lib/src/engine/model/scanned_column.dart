import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'column_kind.dart';

final class ScannedColumn {
  const ScannedColumn({
    required this.field,
    required this.type,
    required this.kind,
    required this.element,
    this.name,
    this.isId = false,
  });

  final String field;
  final DartType type;
  final ColumnKind kind;
  final FieldElement element;
  final String? name;
  final bool isId;
}
