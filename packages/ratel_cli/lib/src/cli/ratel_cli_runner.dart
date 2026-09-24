import 'dart:io';

import 'build_command.dart';
import 'create_command.dart';
import 'dev_command.dart';
import 'ratel_cli_version.dart';
import 'test_command.dart';

final class RatelCliRunner {
  static const _usage = '''
Ratel: annotation-driven backend framework for Dart.

Usage: ratel <command> [arguments]

Commands:
  create <name>                 Scaffold a new Ratel application.
  dev [entrypoint] [-- args]    Run the app and restart it on every change.
  build [entrypoint]            Compile the app to a native binary in build/.
  test [paths] [-- args]        Run the tests with the app's routes wired.

Options:
  -h, --help                    Show this help.
  -v, --version                 Show the version.
''';

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      stdout.writeln(_usage);
      return 0;
    }
    final rest = arguments.skip(1).toList();
    switch (arguments.first) {
      case '-h' || '--help' || 'help':
        stdout.writeln(_usage);
        return 0;
      case '-v' || '--version':
        stdout.writeln(
          'ratel_cli ${RatelCliVersion.current} '
          '(runtime contract ${RatelCliVersion.contract})',
        );
        return 0;
      case 'create':
        return CreateCommand.run(rest);
      case 'dev':
        return DevCommand.run(rest);
      case 'build':
        return BuildCommand.run(rest);
      case 'test':
        return TestCommand.run(rest);
      default:
        stderr
          ..writeln('Unknown command: ${arguments.first}')
          ..writeln(_usage);
        return 64;
    }
  }
}
