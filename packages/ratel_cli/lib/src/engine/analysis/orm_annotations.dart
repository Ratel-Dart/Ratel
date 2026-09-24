import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'package_annotations.dart';

abstract final class OrmAnnotations {
  static const package = 'ratel_orm';
  static const entity = 'Entity';
  static const column = 'Column';
  static const id = 'Id';
  static const transient = 'Transient';
  static const repository = 'RatelRepository';

  static const fieldAnnotations = [column, id, transient];

  static DartObject? first(Element element, String name) {
    for (final carrier in _carriers(element)) {
      final value = PackageAnnotations.first(carrier, package, name);
      if (value != null) return value;
    }
    return null;
  }

  static bool has(Element element, String name) => first(element, name) != null;

  static List<String> present(Element element, List<String> names) => [
        for (final name in names)
          if (has(element, name)) name,
      ];

  static bool isOrmType(DartType type, String name) =>
      PackageAnnotations.isType(type, package, name);

  static bool isOrmLibrary(Uri uri) =>
      PackageAnnotations.isLibrary(uri, package);

  static InterfaceType? repositoryOf(InterfaceElement element) {
    for (final type in element.allSupertypes) {
      if (isOrmType(type, repository)) return type;
    }
    return null;
  }

  static List<Element> _carriers(Element element) => [
        element,
        if (element case FieldElement(:final declaringFormalParameter?))
          declaringFormalParameter,
      ];
}
