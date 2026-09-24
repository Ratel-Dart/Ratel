import 'dart:async';
import 'dart:io';

import '../process/dart_sdk.dart';

final class ServerProcess {
  ServerProcess._(this._process) {
    _process.stdout.listen(stdout.add);
    _process.stderr.listen(stderr.add);
    unawaited(_process.exitCode.then((code) {
      if (!_stopping) {
        stdout.writeln(
          '[ratel] server exited with code $code; waiting for changes',
        );
      }
    }));
  }

  final Process _process;
  bool _stopping = false;

  static Future<ServerProcess> start({
    required String entry,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      DartSdk.dart,
      ['run', entry, ...arguments],
      workingDirectory: workingDirectory,
    );
    return ServerProcess._(process);
  }

  Future<void> stop() async {
    _stopping = true;
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
