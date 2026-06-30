import '../annotations/annotations.dart';

/// The result of matching a request path against a [Route]: the matched [route]
/// and the captured path [params].
class RouteMatch {
  /// The route that matched.
  final Route route;

  /// Path parameters captured from `:name` segments.
  final Map<String, String> params;

  /// Creates a match result.
  RouteMatch(this.route, this.params);
}

/// Resolves an incoming `(method, path)` to a [Route], supporting `:name` path
/// parameters, and reports which methods a path accepts (for `405`/`Allow`).
///
/// Matching is currently a linear scan with per-segment comparison; it can be
/// replaced by a trie later without changing this API.
class Router {
  final List<_CompiledRoute> _compiled;

  /// Builds a router over [routes], compiling each route's path once.
  Router(List<Route> routes)
      : _compiled = routes.map(_CompiledRoute.new).toList(growable: false);

  /// Returns the route matching [method] and [path] with any captured path
  /// parameters, or null when nothing matches.
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

  /// Returns the set of HTTP methods registered for [path] (ignoring method),
  /// used to build the `Allow` header and decide `404` vs `405`.
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
  /// True when this segment is a `:name` capture.
  final bool isParam;

  /// The literal text, or the capture name (without the leading `:`).
  final String value;

  _Segment(String raw)
      : isParam = raw.startsWith(':'),
        value = raw.startsWith(':') ? raw.substring(1) : raw;
}

/// Splits a URL [path] into its non-empty segments, ignoring leading and
/// trailing slashes. `/` and `''` both yield an empty list.
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
