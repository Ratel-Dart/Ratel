import '../annotations/annotations.dart';

class RouteMatch {
  final Route route;

  final Map<String, String> params;

  RouteMatch(this.route, this.params);
}

class Router {
  final List<_CompiledRoute> _compiled;

  Router(List<Route> routes)
      : _compiled = routes.map(_CompiledRoute.new).toList(growable: false);

  RouteMatch? match(String method, String path) {
    final segments = splitPath(path);
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
    final segments = splitPath(path);
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

class _CompiledRoute {
  final Route route;
  final List<_Segment> segments;

  _CompiledRoute(this.route)
      : segments = splitPath(route.path).map(_Segment.new).toList(
              growable: false,
            );
}

class _Segment {
  final bool isParam;

  final String value;

  _Segment(String raw)
      : isParam = raw.startsWith(':'),
        value = raw.startsWith(':') ? raw.substring(1) : raw;
}

List<String> splitPath(String path) {
  var normalized = path;
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.isEmpty) return const [];
  return normalized.split('/');
}

String normaliseSocketPath(String path) => '/${splitPath(path).join('/')}';
