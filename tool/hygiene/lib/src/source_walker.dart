import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class SourceWalker {
  static const _skipped = {'.dart_tool', '.git', '.idea', '.vscode'};
  static const _output = 'build';
  static const _configNames = {'.gitignore', '.gitattributes'};

  static List<String> files(List<String> roots) {
    final found = <String>{};
    for (final root in roots) {
      final absolute = p.normalize(p.absolute(root));
      if (File(absolute).existsSync()) {
        if (_isChecked(absolute)) found.add(absolute);
        continue;
      }
      final directory = Directory(absolute);
      if (!directory.existsSync()) continue;
      for (final entity
          in directory.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = p.normalize(entity.path);
        if (_isSkipped(absolute, path)) continue;
        if (_isChecked(path)) found.add(path);
      }
    }
    return found.toList()..sort();
  }

  static bool isConfig(String path) {
    final name = p.basename(path);
    return name.endsWith('.yaml') ||
        name.endsWith('.yml') ||
        _configNames.contains(name);
  }

  static bool _isSkipped(String root, String path) {
    final segments = p.split(p.relative(path, from: root));
    var directory = root;
    for (final segment in segments.take(segments.length - 1)) {
      if (_skipped.contains(segment)) return true;
      if (segment == _output &&
          File(p.join(directory, 'pubspec.yaml')).existsSync()) {
        return true;
      }
      directory = p.join(directory, segment);
    }
    return false;
  }

  static bool _isChecked(String path) =>
      path.endsWith('.dart') || isConfig(path);
}
