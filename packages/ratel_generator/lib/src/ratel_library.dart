import 'package:analyzer/dart/element/element.dart';

class RatelLibrary {
  const RatelLibrary({
    required this.jsonClasses,
    required this.controllers,
    required this.entities,
  });

  final List<ClassElement> jsonClasses;
  final List<ClassElement> controllers;
  final Map<ClassElement, List<FieldElement>> entities;

  bool get isEmpty =>
      jsonClasses.isEmpty && controllers.isEmpty && entities.isEmpty;

  bool get needsRuntimeImport =>
      jsonClasses.isNotEmpty || controllers.isNotEmpty;

  bool get needsOrmImport => entities.isNotEmpty;
}
