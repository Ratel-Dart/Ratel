import 'package:ratel/runtime.dart';

abstract final class IsolateSetupRecorder {
  static const RatelManifest manifest = RatelManifest(
    isolateSetup: [first, second],
  );

  static final List<String> _calls = [];

  static List<String> get calls => List.unmodifiable(_calls);

  static void first() => _calls.add('first');

  static void second() => _calls.add(
        identical(RatelRuntime.installed, manifest)
            ? 'second, installed'
            : 'second, not installed',
      );
}
