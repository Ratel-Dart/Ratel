import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/process/dart_sdk.dart';

import 'cli_harness.dart';
import 'engine_harness.dart';

abstract final class OrmFixture {
  static const pathVariable = 'RATEL_ORM_PATH';

  static const _skipped = {'.dart_tool', 'build', 'pubspec.lock'};

  static const _lockName = 'ratel_cli_orm_fixture_pub_get.lock';

  static const _staleLock = Duration(minutes: 3);

  static const _lockPoll = Duration(milliseconds: 200);

  static final _dependsOnRatel = RegExp(r'^  ratel:', multiLine: true);

  static String? get localOrm {
    final local = Platform.environment[pathVariable];
    if (local == null || local.isEmpty) return null;
    return p.normalize(p.absolute(local));
  }

  static Future<Directory> copy(String name, Directory parent) async {
    final source = Directory(EngineHarness.fixture(name));
    final target = Directory(p.join(parent.path, name));
    _copy(source, target);
    final pubspec = File(p.join(target.path, 'pubspec.yaml'));
    final original = pubspec.readAsStringSync();
    final overrides = {
      if (_dependsOnRatel.hasMatch(original)) 'ratel': CliHarness.ratelPackage,
      if (localOrm case final local?) 'ratel_orm': local,
    };
    if (overrides.isNotEmpty) {
      final buffer = StringBuffer('$original\ndependency_overrides:\n');
      for (final MapEntry(key: package, value: path) in overrides.entries) {
        buffer
          ..writeln('  $package:')
          ..writeln('    path: ${path.replaceAll(r'\', '/')}');
      }
      pubspec.writeAsStringSync('$buffer');
    }
    final resolved = await _serialized(
      () => Process.run(
        DartSdk.dart,
        ['pub', 'get'],
        workingDirectory: target.path,
      ),
    );
    if (resolved.exitCode != 0) {
      throw StateError(
        'pub get failed for the $name fixture:\n'
        '${resolved.stdout}${resolved.stderr}',
      );
    }
    return target;
  }

  static Future<T> _serialized<T>(Future<T> Function() action) async {
    final lock = File(p.join(Directory.systemTemp.path, _lockName));
    await _acquire(lock);
    try {
      return await action();
    } finally {
      _release(lock);
    }
  }

  static Future<void> _acquire(File lock) async {
    while (true) {
      try {
        lock.createSync(exclusive: true);
        return;
      } on FileSystemException {
        if (_isStale(lock)) _release(lock);
        await Future<void>.delayed(_lockPoll);
      }
    }
  }

  static bool _isStale(File lock) {
    try {
      return DateTime.now().difference(lock.lastModifiedSync()) > _staleLock;
    } on FileSystemException {
      return false;
    }
  }

  static void _release(File lock) {
    try {
      lock.deleteSync();
    } on FileSystemException catch (_) {}
  }

  static void _copy(Directory source, Directory target) {
    target.createSync(recursive: true);
    for (final entity in source.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (_skipped.contains(name)) continue;
      final destination = p.join(target.path, name);
      if (entity is Directory) {
        _copy(entity, Directory(destination));
      } else if (entity is File) {
        entity.copySync(destination);
      }
    }
  }
}
