import 'package:analyzer/dart/element/type.dart';

String nullableDisplay(DartType type) => type.getDisplayString();

String nonNullableDisplay(DartType type) {
  final display = type.getDisplayString();
  return display.endsWith('?')
      ? display.substring(0, display.length - 1)
      : display;
}
