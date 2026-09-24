import 'dart:io';

import 'package:path/path.dart' as p;

import '../process/dart_process.dart';
import 'ratel_project.dart';

abstract final class PubGet {
  static Future<int> ensure(RatelProject project) async {
    final config = packageConfig(project.root);
    if (config != null && !_isStale(config, project)) return 0;
    stdout.writeln('[ratel] resolving dependencies');
    return DartProcess.run(['pub', 'get'], workingDirectory: project.root);
  }

  static File? packageConfig(String root) {
    var directory = Directory(root);
    while (true) {
      final config =
          File(p.join(directory.path, '.dart_tool', 'package_config.json'));
      if (config.existsSync()) return config;
      final parent = directory.parent;
      if (parent.path == directory.path) return null;
      directory = parent;
    }
  }

  static bool _isStale(File config, RatelProject project) {
    final resolved = config.lastModifiedSync();
    final lock = File(p.join(project.root, 'pubspec.lock'));
    return project.pubspec.lastModifiedSync().isAfter(resolved) ||
        (lock.existsSync() && lock.lastModifiedSync().isAfter(resolved));
  }
}
