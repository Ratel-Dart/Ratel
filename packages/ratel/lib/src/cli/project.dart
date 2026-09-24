import 'dart:io';

import 'package:path/path.dart' as p;

import 'pubspec.dart';

class RatelProject {
  final Directory root;

  final String name;

  RatelProject._(this.root, this.name);

  static RatelProject? locate(Directory from) {
    var dir = from.absolute;
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final name = readName(pubspec.readAsStringSync());
        if (name == null) return null;
        return RatelProject._(dir, name);
      }
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  Directory get workDir => Directory(p.join(root.path, '.dart_tool', 'ratel'));

  File? resolveEntrypoint(String? candidate) {
    if (candidate != null) {
      final file = File(p.join(root.path, candidate));
      return file.existsSync() ? file : null;
    }
    final conventional = File(p.join(root.path, 'bin', 'server.dart'));
    if (conventional.existsSync()) return conventional;
    final bin = Directory(p.join(root.path, 'bin'));
    if (!bin.existsSync()) return null;
    final candidates = bin
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    return candidates.length == 1 ? candidates.first : null;
  }

  String entrypointHelp() => 'Could not find the application entrypoint.\n'
      'Create bin/server.dart, or pass one explicitly: ratel dev <path>';

  List<File> generatedLibraries() {
    final found = <File>[];
    for (final dirName in const ['lib', 'bin', 'example']) {
      final dir = Directory(p.join(root.path, dirName));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.ratel.dart')) continue;
        if (!entity.readAsStringSync().contains('void \$registerRatel(')) {
          continue;
        }
        found.add(entity);
      }
    }
    found.sort((a, b) => a.path.compareTo(b.path));
    return found;
  }

  Future<int> ensureCodegenDependencies() async {
    final pubspec = File(p.join(root.path, 'pubspec.yaml')).readAsStringSync();
    final missing = <String>[
      if (!declaresDependency(pubspec, 'build_runner')) 'build_runner',
      if (!declaresDependency(pubspec, 'ratel_generator')) 'ratel_generator',
    ];
    if (missing.isEmpty) return 0;
    stdout.writeln('Adding ${missing.join(', ')}…');
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['pub', 'add', '-d', ...missing],
      workingDirectory: root.path,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  Future<int> runBuildRunner(List<String> args) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'build_runner', ...args, '--delete-conflicting-outputs'],
      workingDirectory: root.path,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}
