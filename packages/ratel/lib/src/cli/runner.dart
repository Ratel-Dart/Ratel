import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bootstrap.dart';
import 'project.dart';
import 'template.dart';

const _usage = '''
Ratel — annotation-driven backend framework for Dart.

Usage: ratel <command> [arguments]

Commands:
  create <name>     Scaffold a new Ratel application.
  dev [entrypoint]  Run the app, regenerating code and restarting on change.
  build [entrypoint]
                    Compile the app to a native binary in build/.

Options:
  -h, --help        Show this help.
  -v, --version     Show the Ratel version.
''';

/// Entry point for the `ratel` command line tool.
class RatelCliRunner {
  /// Runs [args], returning the process exit code.
  Future<int> run(List<String> args) async {
    if (args.isEmpty) {
      stdout.writeln(_usage);
      return 0;
    }
    final command = args.first;
    final rest = args.skip(1).toList();

    switch (command) {
      case '-h':
      case '--help':
      case 'help':
        stdout.writeln(_usage);
        return 0;
      case '-v':
      case '--version':
        stdout.writeln('ratel ${await ratelVersion()}');
        return 0;
      case 'create':
        return _create(rest);
      case 'build':
        return _build(rest);
      case 'dev':
        return _dev(rest);
      default:
        stderr.writeln('Unknown command: $command');
        stderr.writeln(_usage);
        return 64;
    }
  }

  Future<int> _create(List<String> args) async {
    if (args.isEmpty) {
      stderr.writeln('Usage: ratel create <name>');
      return 64;
    }
    final target = Directory(args.first);
    if (target.existsSync() && target.listSync().isNotEmpty) {
      stderr.writeln('Cannot create: ${target.path} exists and is not empty.');
      return 1;
    }
    await scaffold(target, await ratelVersion());
    final name = p.basename(p.absolute(target.path));
    stdout
      ..writeln('Created $name.')
      ..writeln()
      ..writeln('  cd ${target.path}')
      ..writeln('  ratel dev')
      ..writeln();
    return 0;
  }

  Future<int> _build(List<String> args) async {
    final project = RatelProject.locate(Directory.current);
    if (project == null) {
      stderr.writeln('No pubspec.yaml found. Run this inside a Ratel app.');
      return 1;
    }
    final entrypoint =
        project.resolveEntrypoint(args.isEmpty ? null : args.first);
    if (entrypoint == null) {
      stderr.writeln(project.entrypointHelp());
      return 1;
    }

    if (await project.ensureCodegenDependencies() != 0) return 1;

    stdout.writeln('Generating…');
    final generated = await project.runBuildRunner(['build']);
    if (generated != 0) return generated;

    final bootstrap = writeBootstrap(project, entrypoint);
    stdout.writeln('Compiling…');
    final output = p.join(project.root.path, 'build', 'server');
    Directory(p.dirname(output)).createSync(recursive: true);
    final compile = await Process.start(
      Platform.resolvedExecutable,
      ['compile', 'exe', bootstrap, '-o', output],
      workingDirectory: project.root.path,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await compile.exitCode;
    if (code == 0) stdout.writeln('Built ${p.relative(output)}');
    return code;
  }

  Future<int> _dev(List<String> args) async {
    final project = RatelProject.locate(Directory.current);
    if (project == null) {
      stderr.writeln('No pubspec.yaml found. Run this inside a Ratel app.');
      return 1;
    }
    final entrypoint =
        project.resolveEntrypoint(args.isEmpty ? null : args.first);
    if (entrypoint == null) {
      stderr.writeln(project.entrypointHelp());
      return 1;
    }

    if (await project.ensureCodegenDependencies() != 0) return 1;

    final dev = _DevSession(project, entrypoint);
    return dev.run();
  }
}

/// Marks a successful build. `build_runner` words its completion differently
/// when its output is piped rather than attached to a terminal, so both
/// phrasings are matched.
final _buildSucceeded = RegExp(r'Succeeded after|Built with build_runner in');

/// Marks a failed build, after which the previous server is left running.
final _buildFailed = RegExp(r'Failed after|Build failed');

/// Runs `build_runner watch` alongside the application, restarting it whenever
/// a build completes.
///
/// Code generation and file watching are the same child process: reacting to
/// `build_runner watch`'s own build completions avoids running a second watcher
/// and avoids `build` and `watch` contending on the `.dart_tool/build` lock.
class _DevSession {
  _DevSession(this.project, this.entrypoint);

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
