import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'parameter_source.dart';

final class ScannedParameter {
  const ScannedParameter({
    required this.element,
    required this.dartName,
    required this.isNamed,
    required this.source,
    required this.bindingName,
    required this.type,
    required this.isRequired,
  });

  final FormalParameterElement element;
  final String dartName;
  final bool isNamed;
  final ParameterSource source;
  final String bindingName;
  final DartType type;
  final bool isRequired;
}
