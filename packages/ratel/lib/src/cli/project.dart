import 'dart:io';

import 'package:path/path.dart' as p;

import 'pubspec.dart';

/// A Ratel application on disk: its [root] directory and package [name].
class RatelProject {
  /// The directory holding `pubspec.yaml`.
  final Directory root;

  /// The package name declared in `pubspec.yaml`.
  final String name;

  RatelProject._(this.root, this.name);

  /// Walks up from [from] looking for a `pubspec.yaml`, or null when there is
  /// none.
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

  /// The directory the CLI generates into.
  Directory get workDir => Directory(p.join(root.path, '.dart_tool', 'ratel'));

  /// Resolves the application entrypoint from an explicit [candidate], falling
  /// back to `bin/server.dart` or a lone file in `bin/`. Null when ambiguous.
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

  /// Guidance shown when the entrypoint cannot be resolved.
  String entrypointHelp() => 'Could not find the application entrypoint.\n'
      'Create bin/server.dart, or pass one explicitly: ratel dev <path>';

  /// Every generated library exposing a `\$registerRatel()`.
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

  /// Adds `build_runner` and `ratel_generator` to `dev_dependencies` when they
  /// are missing, so the application never has to declare them by hand.
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

  /// Runs `dart run build_runner <args>` in this project.
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
