import 'package:analyzer/dart/element/element.dart';

import 'construction_plan.dart';
import 'scanned_column.dart';

final class ScannedEntity {
  const ScannedEntity({
    required this.element,
    required this.columns,
    required this.construction,
    this.table,
  });

  final ClassElement element;
  final List<ScannedColumn> columns;
  final ConstructionPlan construction;
  final String? table;

  String get name => element.name ?? '';

  ScannedColumn get id => columns.firstWhere((column) => column.isId);
}
