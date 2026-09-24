import '../annotations/annotations.dart';
import '../http/socket_handler.dart';
import 'router.dart';

class RatelRegistry {
  static RatelRegistry current = RatelRegistry();

  final List<Route> routes = [];

  final Map<String, SocketHandler> sockets = {};

  int maxRequestBodyBytes = defaultMaxRequestBodyBytes;

  static const int defaultMaxRequestBodyBytes = 1024 * 1024;

  int maxBodyDrainBytes = defaultMaxBodyDrainBytes;

  static const int defaultMaxBodyDrainBytes = 1024 * 1024;

  static T runScoped<T>(RatelRegistry registry, T Function() register) {
    final previous = current;
    current = registry;
    try {
      return register();
    } finally {
      current = previous;
    }
  }

  void register(Route route) {
    final clash = routes.any(
      (r) => r.path == route.path && r.method == route.method,
    );
    if (clash) {
      throw StateError(
        'Duplicate route registered: ${route.method} ${route.path}',
      );
    }
    routes.add(route);
  }

  void registerSocket(String path, SocketHandler handler) {
    final key = normaliseSocketPath(path);
    if (sockets.containsKey(key)) {
      throw StateError('Duplicate socket registered: $key');
    }
    sockets[key] = handler;
  }

  SocketHandler? socketFor(String path) => sockets[normaliseSocketPath(path)];

  void reset() {
    routes.clear();
    sockets.clear();
  }
}
