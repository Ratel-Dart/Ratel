import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

void requirePublic(ClassElement element, String what) {
  if (!element.isPrivate) return;
  throw InvalidGenerationSourceError(
    '$what must be public. Generated code lives in a separate library and '
    'cannot reference ${element.displayName}. Rename it without the leading '
    'underscore.',
    element: element,
  );
}
