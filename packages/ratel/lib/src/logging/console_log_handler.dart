import 'dart:io';

import 'package:logging/logging.dart';

final class ConsoleLogHandler {
  ConsoleLogHandler({StringSink? out, StringSink? err})
      : out = out ?? _survivingClose(stdout),
        err = err ?? _survivingClose(stderr);

  final StringSink out;

  final StringSink err;

  void call(LogRecord record) {
    final sink = record.level >= Level.WARNING ? err : out;
    try {
      sink.write(format(record));
    } catch (_) {}
  }

  static String format(LogRecord record) {
    final text = StringBuffer()
      ..writeln('${record.time.toUtc().toIso8601String()} '
          '${record.level.name} ${record.loggerName}: ${record.message}');
    final error = record.error;
    if (error != null) text.writeln(_describe(error));
    final stackTrace = record.stackTrace;
    if (stackTrace != null) text.writeln(_describe(stackTrace).trimRight());
    return text.toString();
  }

  static String _describe(Object value) {
    try {
      return '$value';
    } catch (_) {
      return Error.safeToString(value);
    }
  }

  static Stdout _survivingClose(Stdout console) {
    console.done.ignore();
    return console;
  }
}
