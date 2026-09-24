import 'package:analyzer/dart/element/type.dart';

final class ScannedField {
  const ScannedField({required this.name, required this.type});

  final String name;
  final DartType type;
}
