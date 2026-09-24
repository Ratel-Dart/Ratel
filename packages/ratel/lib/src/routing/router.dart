import 'compiled_route.dart';
import 'route.dart';
import 'route_match.dart';
import 'route_path.dart';

final class Router {
  Router(List<Route> routes)
      : _compiled = routes.map(CompiledRoute.new).toList(growable: false);

  final List<CompiledRoute> _compiled;

  RouteMatch? match(String method, String path) {
    final segments = RoutePath.split(path);
    for (final compiled in _compiled) {
      if (compiled.segments.length != segments.length) continue;
      final params = <String, String>{};
      var matched = true;
      for (var i = 0; i < segments.length; i++) {
        final segment = compiled.segments[i];
        if (segment.isParam) {
          params[segment.value] = segments[i];
        } else if (segment.value != segments[i]) {
          matched = false;
          break;
        }
      }
      if (matched && compiled.route.method == method) {
        return RouteMatch(compiled.route, params);
      }
    }
    return null;
  }

  Set<String> allowedMethods(String path) {
    final segments = RoutePath.split(path);
    final methods = <String>{};
    for (final compiled in _compiled) {
      if (compiled.segments.length != segments.length) continue;
      var matched = true;
      for (var i = 0; i < segments.length; i++) {
        final segment = compiled.segments[i];
        if (!segment.isParam && segment.value != segments[i]) {
          matched = false;
          break;
        }
      }
      if (matched) methods.add(compiled.route.method);
    }
    return methods;
  }
}
