import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../engine/diagnostics/diagnostic_printer.dart';
import '../engine/model/generation_mode.dart';
import '../engine/output_writer.dart';
import '../project/prepared_project.dart';
import '../project/pub_get.dart';
import 'project_watcher.dart';
import 'server_process.dart';

final class DevSession {
  DevSession(this.prepared, this.arguments);

  final PreparedProject prepared;
  final List<String> arguments;

  ServerProcess? _server;
  Future<void> _cycles = Future.value();
  final Set<String> _pending = {};
  final _done = Completer<int>();
  bool _stopping = false;

  Future<int> run() async {
    final signals = <StreamSubscription<ProcessSignal>>[
      ProcessSignal.sigint.watch().listen((_) => _stop(0)),
      if (!Platform.isWindows)
        ProcessSignal.sigterm.watch().listen((_) => _stop(0)),
    ];
    final watcher = ProjectWatcher(prepared.project.root);
    final changes = watcher.batches.listen(_enqueue);
    await watcher.ready;
    _enqueue(const {});

    final code = await _done.future;
    await changes.cancel();
    await watcher.close();
    for (final signal in signals) {
      await signal.cancel();
    }
    await _cycles;
    await _server?.stop();
    await prepared.dispose();
    return code;
  }

  void _enqueue(Set<String> paths) {
    _pending.addAll(paths);
    _cycles = _cycles.then((_) => _cycle());
  }

  Future<void> _cycle() async {
    if (_stopping) return;
    final changed = {..._pending};
    _pending.clear();
    if (changed.any(ProjectWatcher.isConfig)) {
      await PubGet.ensure(prepared.project);
      await prepared.reopen();
    } else if (changed.isNotEmpty) {
      await prepared.analyzer.changed(changed);
    }

    final run = prepared.generation(GenerationMode.dev);
    final result = await run.run();
    if (result.diagnostics.isNotEmpty) {
      stdout.writeln(
        DiagnosticPrinter.format(result.diagnostics, prepared.project.root),
      );
    }
    if (result.hasErrors) {
      final errors =
          result.diagnostics.where((diagnostic) => diagnostic.isError).length;
      stdout.writeln(
        '[ratel] $errors ${errors == 1 ? 'error' : 'errors'}; '
        '${_server == null ? 'waiting for a fix' : 'the previous server is still running'}.',
      );
      return;
    }
    OutputWriter.write(run.outputDirectory, result.files);
    if (_stopping) return;
    await _server?.stop();
    final entrypoint = prepared.entrypoint!;
    stdout.writeln(
      '[ratel] starting ${p.relative(entrypoint.path, from: prepared.project.root)}',
    );
    _server = await ServerProcess.start(
      entry: run.entryPath,
      arguments: arguments,
      workingDirectory: prepared.project.root,
    );
  }

  void _stop(int code) {
    if (_stopping) return;
    _stopping = true;
    if (!_done.isCompleted) _done.complete(code);
  }
}
