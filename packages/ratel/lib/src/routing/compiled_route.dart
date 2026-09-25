import 'route.dart';
import 'route_path.dart';
import 'route_segment.dart';

final class CompiledRoute {
  CompiledRoute(this.route)
      : segments = RoutePath.split(route.path)
            .map(RouteSegment.new)
            .toList(growable: false);

  final Route route;
  final List<RouteSegment> segments;

  bool matches(List<String> path) {
    if (segments.length != path.length) return false;
    for (var i = 0; i < path.length; i++) {
      final segment = segments[i];
      if (!segment.isParam && segment.value != path[i]) return false;
    }
    return true;
  }

  Map<String, String> capture(List<String> path) => {
        for (var i = 0; i < segments.length; i++)
          if (segments[i].isParam) segments[i].value: path[i],
      };

  bool isMoreSpecificThan(CompiledRoute other) {
    for (var i = 0; i < segments.length && i < other.segments.length; i++) {
      final isParam = segments[i].isParam;
      if (isParam != other.segments[i].isParam) return !isParam;
    }
    return false;
  }
}
