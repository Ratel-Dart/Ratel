import 'package:analyzer/dart/element/element.dart';

import 'constructor_argument.dart';
import 'scanned_field.dart';

final class ConstructionPlan {
  const ConstructionPlan({
    required this.constructor,
    required this.arguments,
    required this.assignments,
  });

  final ConstructorElement constructor;
  final List<ConstructorArgument> arguments;
  final List<ScannedField> assignments;
}
