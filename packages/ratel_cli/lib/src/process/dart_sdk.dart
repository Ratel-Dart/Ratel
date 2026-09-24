import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class DartSdk {
  static final String root = _locate();

  static String get dart =>
      p.join(root, 'bin', Platform.isWindows ? 'dart.exe' : 'dart');

  static const _sdkExecutables = {'dart', 'dartvm', 'dartaotruntime'};

  static String _locate() {
    final executable =
        File(Platform.resolvedExecutable).resolveSymbolicLinksSync();
    if (_sdkExecutables.contains(p.basenameWithoutExtension(executable))) {
      final candidate = p.dirname(p.dirname(executable));
      if (_isSdk(candidate)) return candidate;
    }
    final onPath = _dartOnPath();
    if (onPath != null) {
      final candidate =
          p.dirname(p.dirname(File(onPath).resolveSymbolicLinksSync()));
      if (_isSdk(candidate)) return candidate;
    }
    throw StateError(
      'Could not find the Dart SDK. Put the `dart` executable on your PATH.',
    );
  }

  static bool _isSdk(String candidate) =>
      File(p.join(candidate, 'version')).existsSync();

  static String? _dartOnPath() {
    final result =
        Process.runSync(Platform.isWindows ? 'where' : 'which', ['dart']);
    if (result.exitCode != 0) return null;
    for (final line in (result.stdout as String).split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && File(trimmed).existsSync()) return trimmed;
    }
    return null;
  }
}
