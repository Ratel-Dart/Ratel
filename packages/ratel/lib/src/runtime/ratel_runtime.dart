import 'ratel_manifest.dart';

abstract final class RatelRuntime {
  static const int contract = 1;

  static RatelManifest? _installed;

  static RatelManifest? get installed => _installed;

  static void install(RatelManifest manifest) {
    final current = _installed;
    if (current == null) {
      _installed = manifest;
      return;
    }
    if (identical(current, manifest)) return;
    throw StateError(
      'A different Ratel manifest is already installed in this isolate.',
    );
  }
}
