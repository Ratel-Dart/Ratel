import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bootstrap.dart';
import 'project.dart';
import 'version.dart';
import 'dev_session.dart';
import 'template.dart';
import 'usage.dart';

class RatelCliRunner {
  Future<int> run(List<String> args) async {
    if (args.isEmpty) {
      stdout.writeln(usage);
      return 0;
    }
    final command = args.first;
    final rest = args.skip(1).toList();

    switch (command) {
      case '-h':
      case '--help':
      case 'help':
        stdout.writeln(usage);
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
        stderr.writeln(usage);
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

    final dev = DevSession(project, entrypoint);
    return dev.run();
  }
}
