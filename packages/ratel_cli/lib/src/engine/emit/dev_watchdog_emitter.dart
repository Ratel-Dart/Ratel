abstract final class DevWatchdogEmitter {
  static const file = 'ratel_dev_watchdog.dart';
  static const className = 'RatelDevWatchdog';

  static String emit() => "import 'dart:io';\n"
      "import 'dart:isolate';\n"
      '\n'
      'abstract final class $className {\n'
      '  static Future<void> attach() =>\n'
      "      Isolate.spawn(_watch, null, debugName: 'ratel_dev_watchdog');\n"
      '\n'
      '  static void _watch(Object? _) {\n'
      '    stdin.listen(\n'
      '      (_) {},\n'
      '      onDone: () => exit(0),\n'
      '      onError: (Object _) => exit(0),\n'
      '    );\n'
      '  }\n'
      '}\n';
}
