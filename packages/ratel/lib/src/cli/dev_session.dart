import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bootstrap.dart';
import 'project.dart';

/// Runs `build_runner watch` alongside the application, restarting it whenever
/// a build completes.
///
/// Code generation and file watching are the same child process: reacting to
/// `build_runner watch`'s own build completions avoids running a second watcher
/// and avoids `build` and `watch` contending on the `.dart_tool/build` lock.
class DevSession {
  DevSession(this.project, this.entrypoint);

  final RatelProject project;
  final File entrypoint;

  Process? _server;
  Process? _watcher;
  var _stopping = false;
  final _done = Completer<int>();

  Future<int> run() async {
    final signals = <StreamSubscription<ProcessSignal>>[
      ProcessSignal.sigint.watch().listen((_) => _stop(0)),
    ];
    if (!Platform.isWindows) {
      signals.add(ProcessSignal.sigterm.watch().listen((_) => _stop(0)));
    }

    _watcher = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'build_runner', 'watch', '--delete-conflicting-outputs'],
      workingDirectory: project.root.path,
    );
    _watcher!.stderr.transform(utf8.decoder).listen(stderr.write);
    _watcher!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onBuildOutput);
    unawaited(_watcher!.exitCode.then((code) {
      if (!_stopping) _stop(code);
    }));

    final code = await _done.future;
    for (final signal in signals) {
      await signal.cancel();
    }
    return code;
  }

  void _onBuildOutput(String line) {
    stdout.writeln(line);
    if (_buildFailed.hasMatch(line)) {
      stdout.writeln('[ratel] build failed; leaving the running server alone');
      return;
    }
    if (_buildSucceeded.hasMatch(line)) unawaited(_restart());
  }

  Future<void> _restart() async {
    if (_stopping) return;
    final previous = _server;
    if (previous != null) {
      previous.kill();
      await previous.exitCode;
    }
    if (_stopping) return;
    final bootstrap = writeBootstrap(project, entrypoint);
    stdout.writeln('[ratel] starting ${p.relative(entrypoint.path)}');
    _server = await Process.start(
      Platform.resolvedExecutable,
      ['run', bootstrap],
      workingDirectory: project.root.path,
      mode: ProcessStartMode.inheritStdio,
    );
  }

  void _stop(int code) {
    if (_stopping) return;
    _stopping = true;
    _server?.kill();
    _watcher?.kill();
    if (!_done.isCompleted) _done.complete(code);
  }
}

/// Marks a successful build. `build_runner` words its completion differently
/// when its output is piped rather than attached to a terminal, so both
/// phrasings are matched.
final _buildSucceeded = RegExp(r'Succeeded after|Built with build_runner in');

/// Marks a failed build, after which the previous server is left running.
final _buildFailed = RegExp(r'Failed after|Build failed');
