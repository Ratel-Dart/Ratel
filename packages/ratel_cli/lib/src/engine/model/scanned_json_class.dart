import 'package:analyzer/dart/element/element.dart';

import 'scanned_field.dart';

final class ScannedJsonClass {
  const ScannedJsonClass({
    required this.element,
    required this.encoded,
    required this.decoded,
    required this.isConstructible,
  });

  final ClassElement element;
  final List<String> encoded;
  final List<ScannedField> decoded;
  final bool isConstructible;
}
