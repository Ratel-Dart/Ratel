import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import 'annotation_checkers.dart';
import 'ratel_library.dart';
import 'visibility_guard.dart';

RatelLibrary scanLibrary(LibraryReader library) {
  final jsonClasses = <ClassElement>[];
  final controllers = <ClassElement>[];

  for (final element in library.classes) {
    if (jsonChecker.hasAnnotationOfExact(element)) {
      requirePublic(element, 'A @Json class');
      jsonClasses.add(element);
    }
    if (element.displayName != 'RatelHandler' &&
        !element.isAbstract &&
        handlerChecker.isAssignableFrom(element)) {
      requirePublic(element, 'A controller');
      controllers.add(element);
    }
  }

  return RatelLibrary(jsonClasses: jsonClasses, controllers: controllers);
}
