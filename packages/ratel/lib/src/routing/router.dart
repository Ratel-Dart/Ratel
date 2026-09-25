import 'compiled_route.dart';
import 'route.dart';
import 'route_match.dart';
import 'route_path.dart';

final class Router {
  Router(List<Route> routes)
      : _compiled = routes.map(CompiledRoute.new).toList(growable: false);

  final List<CompiledRoute> _compiled;

  RouteMatch? match(String method, String path) {
    final segments = RoutePath.decode(path);
    CompiledRoute? best;
    for (final compiled in _compiled) {
      if (compiled.route.method != method) continue;
      if (!compiled.matches(segments)) continue;
      if (best == null || compiled.isMoreSpecificThan(best)) best = compiled;
    }
    if (best == null) return null;
    return RouteMatch(best.route, best.capture(segments));
  }

  Set<String> allowedMethods(String path) {
    final segments = RoutePath.decode(path);
    return {
      for (final compiled in _compiled)
        if (compiled.matches(segments)) compiled.route.method,
    };
  }
}
