import 'dart:async';
import 'dart:io';

import '../process/dart_sdk.dart';

final class ServerProcess {
  ServerProcess._(this._process, this.label) {
    _process.stdout.listen(stdout.add);
    _process.stderr.listen(stderr.add);
    unawaited(_process.exitCode.then((code) {
      _exited = true;
      if (!_stopping) {
        stdout.writeln(
          '[ratel] $label exited with code $code; waiting for changes',
        );
      }
    }));
  }

  final Process _process;
  final String label;
  bool _stopping = false;
  bool _exited = false;

  bool get isRunning => !_exited;

  static Future<ServerProcess> start({
    required String entry,
    required String label,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      DartSdk.dart,
      ['run', entry, ...arguments],
      workingDirectory: workingDirectory,
    );
    return ServerProcess._(process, label);
  }

  Future<void> stop() async {
    _stopping = true;
    if (_exited) {
      await _process.exitCode;
      return;
    }
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/T', '/PID', '${_process.pid}']);
    } else {
      _process.kill();
      final exited = await _process.exitCode
          .then((_) => true)
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (!exited) _process.kill(ProcessSignal.sigkill);
    }
    await _process.exitCode;
  }
}
