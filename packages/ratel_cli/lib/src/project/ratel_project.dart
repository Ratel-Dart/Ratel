import 'dart:io';

import 'package:path/path.dart' as p;

import 'pubspec_reader.dart';

final class RatelProject {
  const RatelProject._(this.root, this.name);

  final String root;
  final String name;

  static const entrypointHelp = 'Could not find the entrypoint.\n'
      'Create bin/server.dart, keep a single .dart file in bin/, or pass it '
      'explicitly: ratel dev <path> or ratel build <path>';

  static RatelProject? locate(Directory from) {
    var directory = Directory(from.absolute.resolveSymbolicLinksSync());
    while (true) {
      final pubspec = File(p.join(directory.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final name = PubspecReader.name(pubspec.readAsStringSync());
        if (name == null) return null;
        return RatelProject._(p.normalize(directory.path), name);
      }
      final parent = directory.parent;
      if (parent.path == directory.path) return null;
      directory = parent;
    }
  }

  File get pubspec => File(p.join(root, 'pubspec.yaml'));

  File? resolveEntrypoint(String? candidate) {
    if (candidate != null) {
      final file = File(p.normalize(p.join(root, candidate)));
      return file.existsSync() ? file : null;
    }
    final conventional = File(p.join(root, 'bin', 'server.dart'));
    if (conventional.existsSync()) return conventional;
    final bin = Directory(p.join(root, 'bin'));
    if (!bin.existsSync()) return null;
    final candidates = bin
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    return candidates.length == 1 ? candidates.single : null;
  }
}
