import 'dart:io';

import 'package:path/path.dart' as p;

import 'generated_file.dart';

abstract final class OutputWriter {
  static bool write(String directory, List<GeneratedFile> files) {
    final folder = Directory(directory)..createSync(recursive: true);
    final wanted = <String>{};
    var changed = false;
    for (final generated in files) {
      final path = p.normalize(p.join(directory, generated.relativePath));
      wanted.add(path);
      final file = File(path);
      if (file.existsSync() && file.readAsStringSync() == generated.contents) {
        continue;
      }
      file.parent.createSync(recursive: true);
      final staged = File('$path.tmp')
        ..writeAsStringSync(generated.contents, flush: true);
      if (file.existsSync()) file.deleteSync();
      staged.renameSync(path);
      changed = true;
    }
    for (final entity in folder.listSync(recursive: true)) {
      if (entity is File && !wanted.contains(p.normalize(entity.path))) {
        entity.deleteSync();
        changed = true;
      }
    }
    return changed;
  }
}
