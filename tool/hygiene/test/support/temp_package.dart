import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_hygiene/src/source_file.dart';

final class TempPackage {
  TempPackage._(this.root);

  final String root;

  static Future<TempPackage> create({bool library = true}) async {
    final directory = await Directory.systemTemp.createTemp('hygiene');
    final package = TempPackage._(directory.path)
      ..write('pubspec.yaml', 'name: sample\n');
    if (library) package.write('lib/sample.dart', "export 'src/a.dart';\n");
    return package;
  }

  String write(String relative, String contents) {
    final file = File(p.join(root, relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(contents);
    return file.path;
  }

  SourceFile file(String relative, String contents) =>
      SourceFile(write(relative, contents));

  Future<void> delete() => Directory(root).delete(recursive: true);
}
