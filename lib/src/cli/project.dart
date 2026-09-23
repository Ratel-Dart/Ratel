import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

const _fallbackVersion = '2.0.0-dev.6';

final _namePattern = RegExp(r'^name:\s*(\S+)\s*$', multiLine: true);
final _versionPattern = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);

/// The Ratel version, read from the `ratel` package's own pubspec.
Future<String> ratelVersion() async {
  final resolved =
      await Isolate.resolvePackageUri(Uri.parse('package:ratel/ratel.dart'));
  if (resolved == null || !resolved.isScheme('file')) return _fallbackVersion;
  final pubspec = File(
    p.join(p.dirname(p.dirname(resolved.toFilePath())), 'pubspec.yaml'),
  );
  if (!pubspec.existsSync()) return _fallbackVersion;
  final match = _versionPattern.firstMatch(pubspec.readAsStringSync());
  return match?.group(1) ?? _fallbackVersion;
}

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
        final match = _namePattern.firstMatch(pubspec.readAsStringSync());
        if (match == null) return null;
        return RatelProject._(dir, match.group(1)!);
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
      if (!pubspec.contains('build_runner')) 'build_runner',
      if (!pubspec.contains('ratel_generator')) 'ratel_generator',
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
