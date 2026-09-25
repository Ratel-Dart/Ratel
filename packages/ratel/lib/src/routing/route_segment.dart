import 'route_path.dart';

final class RouteSegment {
  RouteSegment(String raw)
      : isParam = raw.startsWith(':'),
        value = raw.startsWith(':')
            ? raw.substring(1)
            : RoutePath.decodeLiteral(raw);

  final bool isParam;
  final String value;
}
