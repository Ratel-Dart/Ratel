import 'package:analyzer/dart/element/element.dart';

Iterable<FieldElement> serializableFields(ClassElement element) =>
    element.fields.where(
      (f) => !f.isStatic && !f.isPrivate && f.isOriginDeclaration,
    );

Iterable<GetterElement> serializableGetters(ClassElement element) =>
    element.getters.where(
      (g) => !g.isStatic && !g.isPrivate && g.isOriginDeclaration,
    );

Iterable<FieldElement> columnFields(
  ClassElement element,
  bool Function(FieldElement field) isColumn,
) =>
    element.fields.where(
      (f) => !f.isStatic && f.isOriginDeclaration && isColumn(f),
    );

bool canConstruct(ClassElement element) =>
    element.constructors.any((c) => c.isDefaultConstructor);
