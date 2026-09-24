import '../binding/route_binder.dart';
import '../http/socket_handler.dart';
import '../routing/route.dart';
import '../routing/route_path.dart';
import '../runtime/ratel_manifest.dart';
import '../runtime/ratel_runtime.dart';
import '../serialization/json_codecs.dart';

class RatelRegistry {
  RatelRegistry({this.codecs = const JsonCodecs.empty()});

  factory RatelRegistry.fromManifest(RatelManifest manifest) {
    final registry = RatelRegistry(codecs: JsonCodecs(manifest.jsonCodecs));
    final binder = RouteBinder(registry);
    for (final controller in manifest.controllers) {
      controller.bindWith(binder);
    }
    return registry;
  }

  factory RatelRegistry.installed() {
    final manifest = RatelRuntime.installed;
    if (manifest == null) throw StateError(_missingManifest);
    return RatelRegistry.fromManifest(manifest);
  }

  static const _missingManifest =
      'No Ratel route manifest is installed in this isolate, so RatelServer '
      'would serve no routes. Controllers are discovered by the ratel CLI: run '
      'the app with `ratel dev`, compile it with `ratel build`, and run its '
      'tests with `ratel test`. Plain `dart run`, `dart compile exe` and '
      '`dart test` skip discovery. To serve hand-built routes, pass '
      '`registry:` to RatelServer. In an isolate you spawn yourself, start it '
      'through RatelCluster.run so the manifest is forwarded.';

  final JsonCodecs codecs;

  final List<Route> routes = [];

  final Map<String, SocketHandler> sockets = {};

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
    final key = RoutePath.normalize(path);
    if (sockets.containsKey(key)) {
      throw StateError('Duplicate socket registered: $key');
    }
    sockets[key] = handler;
  }

  SocketHandler? socketFor(String path) => sockets[RoutePath.normalize(path)];
}
