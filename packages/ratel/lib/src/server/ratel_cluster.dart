import 'dart:io';
import 'dart:isolate';

import '../runtime/ratel_manifest.dart';
import '../runtime/ratel_runtime.dart';

abstract final class RatelCluster {
  static Future<void> run(
    void Function(List<String> args) entryPoint, {
    int? isolates,
    List<String> args = const [],
  }) async {
    final count = (isolates == null || isolates <= 0)
        ? Platform.numberOfProcessors
        : isolates;
    final manifest = RatelRuntime.installed;
    for (var i = 1; i < count; i++) {
      await Isolate.spawn(_start, (manifest, entryPoint, args));
    }
    entryPoint(args);
  }

  static void _start(
    (RatelManifest?, void Function(List<String>), List<String>) message,
  ) {
    final (manifest, entryPoint, args) = message;
    if (manifest != null) RatelRuntime.install(manifest);
    entryPoint(args);
  }
}
