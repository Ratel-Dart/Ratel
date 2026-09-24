import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

final class ScannedField {
  const ScannedField({
    required this.name,
    required this.type,
    required this.element,
    this.startsUnset = false,
  });

  final String name;
  final DartType type;
  final Element element;
  final bool startsUnset;
}
