import 'package:analyzer/dart/element/element.dart';

abstract final class ElementQueries {
  static Iterable<FieldElement> serializableFields(ClassElement element) =>
      element.fields.where(
        (field) =>
            !field.isStatic && !field.isPrivate && field.isOriginDeclaration,
      );

  static Iterable<GetterElement> serializableGetters(ClassElement element) =>
      element.getters.where(
        (getter) =>
            !getter.isStatic && !getter.isPrivate && getter.isOriginDeclaration,
      );

  static bool canConstruct(ClassElement element) =>
      !element.isAbstract &&
      element.constructors.any(
        (constructor) =>
            constructor.isDefaultConstructor && !constructor.isPrivate,
      );
}
