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
}
