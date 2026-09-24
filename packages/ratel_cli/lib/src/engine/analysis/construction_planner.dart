import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../model/construction_plan.dart';
import '../model/constructor_argument.dart';
import '../model/scanned_field.dart';
import 'element_queries.dart';

abstract final class ConstructionPlanner {
  static ({ConstructionPlan? plan, String? problem}) plan(
    InterfaceType type, {
    List<ScannedField>? properties,
    String matched = 'field or getter',
  }) {
    final element = type.element;
    final name = element.name ?? '';
    if (element is! ClassElement || element.isAbstract || element.isSealed) {
      return (plan: null, problem: '$name is abstract');
    }
    final constructor = type.constructors
        .where((constructor) =>
            constructor.name == 'new' && !constructor.isPrivate)
        .firstOrNull;
    if (constructor == null) {
      return (plan: null, problem: '$name has no public unnamed constructor');
    }
    final byName = {
      for (final property in properties ?? ElementQueries.properties(type))
        property.name: property,
    };
    final arguments = <ConstructorArgument>[];
    final skipped = <ConstructorArgument>[];
    for (final parameter in constructor.formalParameters) {
      final property = _property(parameter, byName);
      final argument = ConstructorArgument(
        element: parameter,
        name: parameter.name ?? '',
        isNamed: parameter.isNamed,
        property: property,
        type: parameter.type,
        isRequired: parameter.isRequiredPositional || parameter.isRequiredNamed,
        defaultValue: _default(parameter),
      );
      if (property == null) {
        if (argument.isRequired) {
          return (
            plan: null,
            problem: 'the required constructor parameter ${argument.name} '
                'matches no $matched of $name',
          );
        }
        if (!argument.isNamed) skipped.add(argument);
        continue;
      }
      if (!argument.isNamed) {
        arguments.addAll(skipped);
        skipped.clear();
      }
      arguments.add(argument);
    }
    final covered = {for (final argument in arguments) argument.property};
    return (
      plan: ConstructionPlan(
        constructor: constructor,
        arguments: arguments,
        assignments: [
          for (final field in ElementQueries.assignableFields(type))
            if (!covered.contains(field.name) && byName.containsKey(field.name))
              field,
        ],
      ),
      problem: null,
    );
  }

  static String? _property(
    FormalParameterElement parameter,
    Map<String, ScannedField> properties,
  ) {
    FormalParameterElement? origin = parameter;
    while (origin is SuperFormalParameterElement) {
      origin = origin.superConstructorParameter;
    }
    if (origin is FieldFormalParameterElement) {
      final field = origin.field;
      final name = field?.name;
      if (field != null && !field.isPrivate && properties.containsKey(name)) {
        return name;
      }
    }
    for (final candidate in [origin?.name, parameter.name]) {
      if (candidate != null && properties.containsKey(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  static DartObject? _default(FormalParameterElement parameter) {
    FormalParameterElement? current = parameter;
    while (current != null) {
      if (current.hasDefaultValue) return current.computeConstantValue();
      current = current is SuperFormalParameterElement
          ? current.superConstructorParameter
          : null;
    }
    return null;
  }
}
