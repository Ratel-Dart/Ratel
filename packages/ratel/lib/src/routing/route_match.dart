import 'route.dart';

final class RouteMatch {
  RouteMatch(this.route, this.params);

  final Route route;
  final Map<String, String> params;
}
