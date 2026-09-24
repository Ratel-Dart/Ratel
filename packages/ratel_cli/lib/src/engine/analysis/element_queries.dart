import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../model/scanned_field.dart';

abstract final class ElementQueries {
  static const _objectMembers = {'hashCode', 'runtimeType'};

  static Iterable<FieldElement> serializableFields(InterfaceElement element) =>
      element.fields.where(
        (field) =>
            !field.isStatic &&
            !field.isPrivate &&
            (field.isOriginDeclaration ||
                field.isOriginDeclaringFormalParameter),
      );

  static Iterable<GetterElement> serializableGetters(
    InterfaceElement element,
  ) =>
      element.getters.where(
        (getter) =>
            !getter.isStatic &&
            !getter.isPrivate &&
            getter.isOriginDeclaration &&
            !_objectMembers.contains(getter.name),
      );

  static bool canConstruct(ClassElement element) =>
      !element.isAbstract &&
      element.constructors.any(
        (constructor) =>
            constructor.isDefaultConstructor && !constructor.isPrivate,
      );

  static bool declaresName(DartType type) {
    if (type is! InterfaceType) return false;
    final getter = type.lookUpGetter('name', type.element.library);
    return getter != null && !getter.library.uri.isScheme('dart');
  }

  static List<InterfaceType> lineage(InterfaceType type) {
    final chain = <InterfaceType>[];
    InterfaceType? current = type;
    while (current != null && !_isSdk(current)) {
      chain
        ..add(current)
        ..addAll(current.mixins.reversed.where((mixin) => !_isSdk(mixin)));
      current = current.superclass;
    }
    return chain.reversed.toList();
  }

  static bool _isSdk(InterfaceType type) =>
      type.element.library.uri.isScheme('dart');

  static List<ScannedField> properties(InterfaceType type) {
    final byName = <String, ScannedField>{};
    for (final level in lineage(type)) {
      for (final field in serializableFields(level.element)) {
        final name = field.name ?? '';
        byName[name] = ScannedField(
          name: name,
          type: level.getGetter(name)?.returnType ?? field.type,
          element: field,
        );
      }
      for (final getter in serializableGetters(level.element)) {
        final name = getter.name ?? '';
        byName[name] = ScannedField(
          name: name,
          type: level.getGetter(name)?.returnType ?? getter.returnType,
          element: getter,
        );
      }
    }
    return byName.values.toList();
  }

  static List<ScannedField> assignableFields(InterfaceType type) {
    final byName = <String, ScannedField>{};
    for (final level in lineage(type)) {
      for (final field in serializableFields(level.element)) {
        final unset = field.isLate && !field.hasInitializer;
        if (field.isConst) continue;
        if (field.isFinal ? !unset : field.setter == null) continue;
        final name = field.name ?? '';
        byName[name] = ScannedField(
          name: name,
          type: level.getGetter(name)?.returnType ?? field.type,
          element: field,
          startsUnset: unset,
        );
      }
    }
    return byName.values.toList();
  }
}
