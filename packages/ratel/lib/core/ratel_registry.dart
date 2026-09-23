import '../annotations/annotations.dart';
import '../http/socket_handler.dart';
import 'router.dart';

/// The routes, sockets and request limits one server runs with.
///
/// Generated code registers into [current], and a server that is not given a
/// registry of its own adopts it — so a single-server application never sees
/// this type. Two servers in one isolate, or a test that wants its own routes,
/// pass a registry instead of sharing the ambient one:
///
/// ```dart
/// final registry = RatelRegistry();
/// RatelRegistry.runScoped(registry, $registerRatel);
/// final server = RatelServer(port: 8080, registry: registry);
/// ```
class RatelRegistry {
  /// The registry generated code writes to, and the default for a server that
  /// is given none.
  static RatelRegistry current = RatelRegistry();

  /// Registered HTTP routes, in registration order.
  final List<Route> routes = [];

  /// Registered WebSocket handlers, keyed by normalised path.
  final Map<String, SocketHandler> sockets = {};

  /// Maximum accepted request body size, in bytes. Set from
  /// `RatelServer(maxRequestBodyBytes: ...)`.
  int maxRequestBodyBytes = defaultMaxRequestBodyBytes;

  /// The body limit a server falls back to: 1 MiB.
  static const int defaultMaxRequestBodyBytes = 1024 * 1024;

  /// Runs [register] with [registry] installed as [current], then restores the
  /// previous one. This is how generated `$registerRatel()` fills a registry
  /// other than the ambient one.
  static T runScoped<T>(RatelRegistry registry, T Function() register) {
    final previous = current;
    current = registry;
    try {
      return register();
    } finally {
      current = previous;
    }
  }

  /// Registers [route], rejecting a duplicate `method`+`path` pair.
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

  /// Registers [handler] for WebSocket upgrades on [path], rejecting a second
  /// registration for the same path.
  void registerSocket(String path, SocketHandler handler) {
    final key = normaliseSocketPath(path);
    if (sockets.containsKey(key)) {
      throw StateError('Duplicate socket registered: $key');
    }
    sockets[key] = handler;
  }

  /// The handler accepting WebSocket upgrades on [path], or null when none is
  /// registered for it.
  SocketHandler? socketFor(String path) => sockets[normaliseSocketPath(path)];

  /// Forgets every registered route and socket.
  ///
  /// [maxRequestBodyBytes] is left alone: it belongs to the server that set it,
  /// and a server is often constructed before the routes are registered.
  void reset() {
    routes.clear();
    sockets.clear();
  }
}
