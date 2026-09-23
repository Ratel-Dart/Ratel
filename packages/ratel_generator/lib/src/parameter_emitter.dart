import 'package:analyzer/dart/element/element.dart';

import 'annotation_checkers.dart';
import 'constant_values.dart';
import 'cross_library_reference.dart';
import 'generation_context.dart';
import 'type_display.dart';

String emitArgument(FormalParameterElement param, GenerationContext ctx) {
  final full = nullableDisplay(param.type);
  final base = nonNullableDisplay(param.type);

  if (bodyChecker.hasAnnotationOf(param)) {
    return '${fromJsonReference(param.type, ctx)}(jsonBody)';
  }
  final path = pathParamChecker.firstAnnotationOf(param);
  if (path != null) {
    final name = readString(path, 'name');
    return "_r.coerceParam('$name', ctx.pathParams['$name'], $base) as $full";
  }
  if (paramChecker.hasAnnotationOf(param)) {
    final name = param.displayName;
    return "_r.coerceParam('$name', "
        "ctx.request.uri.queryParameters['$name'], $base) as $full";
  }
  final header = headerChecker.firstAnnotationOf(param);
  if (header != null) {
    final name = readString(header, 'name');
    return "_r.coerceParam('$name', ctx.request.headers.value('$name'), "
        "$base) as $full";
  }
  final cookie = cookieChecker.firstAnnotationOf(param);
  if (cookie != null) {
    final name = readString(cookie, 'name');
    return "_r.coerceParam('$name', "
        "_r.cookieValue(ctx.request.cookies, '$name'), $base) as $full";
  }
  return 'null';
}
