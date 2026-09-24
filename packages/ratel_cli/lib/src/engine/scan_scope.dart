import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class ScanScope {
  static List<String> files(String root, {String? entrypoint}) {
    final directories = <String>{p.join(root, 'lib')};
    final extra = <String>{};
    if (entrypoint != null) {
      final segments = p.split(p.relative(entrypoint, from: root));
      if (segments.length > 1) {
        directories.add(p.join(root, segments.first));
      } else {
        extra.add(p.normalize(entrypoint));
      }
    }
    final found = <String>{...extra};
    for (final directory in directories) {
      final folder = Directory(directory);
      if (!folder.existsSync()) continue;
      for (final entity
          in folder.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = p.normalize(entity.absolute.path);
        if (_isCandidate(path, root)) found.add(path);
      }
    }
    return found.toList()..sort();
  }

  static bool _isCandidate(String path, String root) {
    if (!path.endsWith('.dart') || path.endsWith('.ratel.dart')) return false;
    final segments = p.split(p.relative(path, from: root));
    return !segments.any((segment) => segment.startsWith('.'));
  }
}
