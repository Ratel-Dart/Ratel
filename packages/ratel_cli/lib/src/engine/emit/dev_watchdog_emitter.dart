abstract final class DevWatchdogEmitter {
  static const file = 'ratel_dev_watchdog.dart';
  static const className = 'RatelDevWatchdog';

  static String emit() => "import 'dart:io';\n"
      '\n'
      'abstract final class $className {\n'
      '  static void attach() {\n'
      '    stdin.listen(\n'
      '      (_) {},\n'
      '      onDone: () => exit(0),\n'
      '      onError: (Object _) => exit(0),\n'
      '    );\n'
      '  }\n'
      '}\n';
}
