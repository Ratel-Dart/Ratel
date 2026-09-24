import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

final class ConstructorArgument {
  const ConstructorArgument({
    required this.element,
    required this.name,
    required this.isNamed,
    required this.property,
    required this.type,
    required this.isRequired,
    required this.defaultValue,
  });

  final FormalParameterElement element;
  final String name;
  final bool isNamed;
  final String? property;
  final DartType type;
  final bool isRequired;
  final DartObject? defaultValue;
}
