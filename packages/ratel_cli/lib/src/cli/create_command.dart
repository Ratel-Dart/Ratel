import 'dart:io';

import 'package:path/path.dart' as p;

import '../project/project_scaffold.dart';
import 'ratel_cli_version.dart';

abstract final class CreateCommand {
  static int run(List<String> arguments) {
    if (arguments.isEmpty) {
      stderr.writeln('Usage: ratel create <name>');
      return 64;
    }
    final target = Directory(arguments.first);
    if (target.existsSync() && target.listSync().isNotEmpty) {
      stderr.writeln('Cannot create: ${target.path} exists and is not empty.');
      return 1;
    }
    ProjectScaffold.create(target, RatelCliVersion.current);
    stdout
      ..writeln('Created ${p.basename(p.absolute(target.path))}.')
      ..writeln()
      ..writeln('  cd ${target.path}')
      ..writeln('  ratel dev')
      ..writeln();
    return 0;
  }
}
