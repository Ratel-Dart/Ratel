import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class TestSuites {
  static List<String> find(String root, List<String> paths) {
    final targets = paths.isEmpty ? [p.join(root, 'test')] : paths;
    final suites = <String>{};
    for (final target in targets) {
      final absolute = p.normalize(p.join(root, target));
      if (File(absolute).existsSync()) {
        suites.add(absolute);
        continue;
      }
      final directory = Directory(absolute);
      if (!directory.existsSync()) continue;
      for (final entity
          in directory.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('_test.dart')) {
          final path = p.normalize(entity.absolute.path);
          final hidden = p
              .split(p.relative(path, from: root))
              .any((segment) => segment.startsWith('.'));
          if (!hidden) suites.add(path);
        }
      }
    }
    return suites.toList()..sort();
  }
}
