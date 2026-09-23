import 'dart:io';
import 'dart:isolate';

/// Runs [entryPoint] on several isolates so an application can use more than
/// one CPU core.
///
/// Spawns `isolates - 1` extra isolates — defaulting to
/// [Platform.numberOfProcessors] when [isolates] is null or not positive — and
/// runs [entryPoint] on each of them and on the calling isolate. [args] is
/// passed to every invocation.
///
/// [entryPoint] must be a top-level or static function, because that is what
/// `Isolate.spawn` can send. It has to do the whole startup itself: isolates
/// share no memory, so each one registers its own routes and binds its own
/// socket. The server must be created with `shared: true` so they can all
/// listen on the same port and let the OS spread connections across them.
///
/// ```dart
/// void main() => runCluster(serve);
///
/// void serve(List<String> args) {
///   $registerRatel();
///   RatelServer(port: 8080, shared: true).startServer();
/// }
/// ```
Future<void> runCluster(
  void Function(List<String> args) entryPoint, {
  int? isolates,
  List<String> args = const [],
}) async {
  final count = (isolates == null || isolates <= 0)
      ? Platform.numberOfProcessors
      : isolates;
  for (var i = 1; i < count; i++) {
    await Isolate.spawn(entryPoint, args);
  }
  entryPoint(args);
}
