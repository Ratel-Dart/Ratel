import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'annotation_checkers.dart';
import 'element_queries.dart';
import 'generated_library_uri.dart';
import 'generation_context.dart';
import 'type_display.dart';

String fromJsonReference(DartType type, GenerationContext ctx) {
  final element = type.element;
  if (element is! ClassElement) {
    throw InvalidGenerationSourceError(
      'A @Body() parameter must be a class annotated with @Json(); '
      'got ${nonNullableDisplay(type)}.',
    );
  }
  if (!jsonChecker.hasAnnotationOfExact(element)) {
    throw InvalidGenerationSourceError(
      'The @Body() type ${element.displayName} is not annotated with @Json(), '
      'so no deserializer is generated for it. Add @Json() to '
      '${element.displayName}.',
      element: element,
    );
  }
  if (!canConstruct(element)) {
    throw InvalidGenerationSourceError(
      'The @Body() type ${element.displayName} has no zero-argument '
      'constructor, so it cannot be deserialized. Give ${element.displayName} '
      'a constructor whose parameters are all optional.',
      element: element,
    );
  }
  final name = '\$${element.displayName}FromJson';
  if (element.library == ctx.library.element) return name;
  return '${ctx.imports.prefixFor(generatedLibraryUri(element, ctx.buildStep))}'
      '.$name';
}
