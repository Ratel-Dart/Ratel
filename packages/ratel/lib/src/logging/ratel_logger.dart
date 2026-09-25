import 'dart:async';

import 'package:logging/logging.dart';

import 'console_log_handler.dart';

abstract final class RatelLogger {
  static final Logger instance = Logger('ratel');

  static ConsoleLogHandler console = ConsoleLogHandler();

  static StreamSubscription<LogRecord>? _consoleSubscription;

  static void attachConsole() {
    _consoleSubscription ??= instance.onRecord.where(_isOwn).listen(
          (record) => console(record),
          onDone: () => _consoleSubscription = null,
        );
  }

  static bool _isOwn(LogRecord record) =>
      record.loggerName == instance.fullName ||
      record.loggerName.startsWith('${instance.fullName}.');
}
