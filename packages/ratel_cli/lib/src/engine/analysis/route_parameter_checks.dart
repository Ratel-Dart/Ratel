import 'package:analyzer/dart/element/element.dart';

import '../diagnostics/diagnostic_codes.dart';
import '../diagnostics/element_diagnostics.dart';
import '../diagnostics/ratel_diagnostic.dart';
import '../model/parameter_source.dart';
import '../model/scanned_route.dart';

abstract final class RouteParameterChecks {
  static void check(
    ClassElement controller,
    List<ScannedRoute> routes,
    List<RatelDiagnostic> diagnostics,
  ) {
    if (routes.isEmpty) return;
    final owner = '${controller.name}.${routes.first.methodName}';
    for (final parameter in routes.first.parameters) {
      if (parameter.source != ParameterSource.unbound) continue;
      diagnostics.add(ElementDiagnostics.at(
        parameter.element,
        DiagnosticCodes.unboundParameter,
        'The parameter ${parameter.dartName} of $owner has no binding '
        'annotation, so Ratel has no request value to pass to it. Annotate '
        "it with @PathParam('name'), @Param(), @Header('name'), "
        "@CookieParam('name') or @Body(), or type it as RequestContext or "
        'MultipartData.',
      ));
    }
    for (final route in routes) {
      final segments = [
        for (final segment in route.path.split('/'))
          if (segment.startsWith(':')) segment.substring(1),
      ];
      for (final parameter in route.parameters) {
        if (parameter.source != ParameterSource.path) continue;
        final name = parameter.bindingName;
        if (segments.contains(name)) continue;
        final known = segments.isEmpty
            ? 'The path declares no :name segments'
            : 'The path declares ${segments.map((s) => ':$s').join(', ')}';
        diagnostics.add(ElementDiagnostics.at(
          parameter.element,
          DiagnosticCodes.unknownPathParam,
          "The @PathParam('$name') on the parameter ${parameter.dartName} of "
          '$owner names no :$name segment of ${route.verb} ${route.path}. '
          '$known; rename the @PathParam or add :$name to the route path.',
        ));
      }
    }
  }
}
