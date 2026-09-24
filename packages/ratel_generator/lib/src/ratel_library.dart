import 'package:analyzer/dart/element/element.dart';

class RatelLibrary {
  const RatelLibrary({
    required this.jsonClasses,
    required this.controllers,
  });

  final List<ClassElement> jsonClasses;
  final List<ClassElement> controllers;

  bool get isEmpty => jsonClasses.isEmpty && controllers.isEmpty;
}
