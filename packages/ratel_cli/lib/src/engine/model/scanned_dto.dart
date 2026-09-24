import 'package:analyzer/dart/element/type.dart';

import 'construction_plan.dart';
import 'scanned_field.dart';

final class ScannedDto {
  const ScannedDto({
    required this.type,
    required this.encodes,
    required this.decodes,
    required this.properties,
    required this.decoding,
    this.usesToJson = false,
    this.usesFromJson = false,
  });

  final InterfaceType type;
  final bool encodes;
  final bool decodes;
  final List<ScannedField> properties;
  final ConstructionPlan? decoding;
  final bool usesToJson;
  final bool usesFromJson;
}
