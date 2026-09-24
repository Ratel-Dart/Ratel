import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

abstract final class PackageAnnotations {
  static DartObject? first(Element element, String package, String name) {
    for (final annotation in element.metadata.annotations) {
      final value = annotation.computeConstantValue();
      final type = value?.type;
      if (type != null && isType(type, package, name)) return value;
    }
    return null;
  }

  static bool has(Element element, String package, String name) =>
      first(element, package, name) != null;

  static bool isType(DartType type, String package, String name) {
    if (type is! InterfaceType) return false;
    final element = type.element;
    return element.name == name && isLibrary(element.library.uri, package);
  }

  static bool isLibrary(Uri uri, String package) =>
      uri.isScheme('package') &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == package;
}
