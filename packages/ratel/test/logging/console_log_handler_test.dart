import 'package:logging/logging.dart';
import 'package:ratel/src/logging/console_log_handler.dart';
import 'package:test/test.dart';

import '../support/fakes/closed_string_sink.dart';
import '../support/fixtures/models/unprintable_failure.dart';

void main() {
  final out = StringBuffer();
  final err = StringBuffer();
  final handler = ConsoleLogHandler(out: out, err: err);

  setUp(() {
    out.clear();
    err.clear();
  });

  test('prints one line with the UTC time, level, logger and message', () {
    handler(LogRecord(Level.INFO, 'Received SIGINT', 'ratel'));

    expect(
      out.toString(),
      matches(RegExp(
        r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z INFO ratel: Received SIGINT\n$',
      )),
    );
    expect(err.toString(), isEmpty);
  });

  test('prints the error and its stack trace below the line', () {
    final stackTrace = StackTrace.fromString('#0      Boom.explode\n');
    handler(LogRecord(
      Level.SEVERE,
      'Unhandled error [id-0] GET /boom',
      'ratel',
      StateError('kaboom'),
      stackTrace,
    ));

    final lines = err.toString().split('\n');
    expect(
        lines[0], endsWith(' SEVERE ratel: Unhandled error [id-0] GET /boom'));
    expect(lines.sublist(1), ['Bad state: kaboom', '#0      Boom.explode', '']);
    expect(out.toString(), isEmpty);
  });

  test('sends WARNING and above to err and the rest to out', () {
    handler(LogRecord(Level.FINE, 'fine', 'ratel'));
    handler(LogRecord(Level.INFO, 'info', 'ratel'));
    handler(LogRecord(Level.WARNING, 'warning', 'ratel'));
    handler(LogRecord(Level.SHOUT, 'shout', 'ratel'));

    expect(out.toString(), allOf(contains('fine'), contains('info')));
    expect(out.toString(), isNot(contains('warning')));
    expect(err.toString(), allOf(contains('warning'), contains('shout')));
    expect(err.toString(), isNot(contains('info')));
  });

  test('prints an error whose toString throws without throwing itself', () {
    final stackTrace = StackTrace.fromString('#0      Boom.explode\n');
    handler(LogRecord(
      Level.SEVERE,
      'Unhandled error [id-0] GET /unprintable',
      'ratel',
      UnprintableFailure(),
      stackTrace,
    ));

    final lines = err.toString().split('\n');
    expect(
      lines[0],
      endsWith(' SEVERE ratel: Unhandled error [id-0] GET /unprintable'),
    );
    expect(lines.sublist(1), [
      "Instance of 'UnprintableFailure'",
      '#0      Boom.explode',
      '',
    ]);
  });

  test('drops the record when the sink throws', () {
    final closed = ConsoleLogHandler(
      out: ClosedStringSink(),
      err: ClosedStringSink(),
    );

    expect(
      () => closed(LogRecord(Level.INFO, 'Received SIGINT', 'ratel')),
      returnsNormally,
    );
    expect(
      () => closed(LogRecord(Level.SEVERE, 'boom', 'ratel', StateError('x'))),
      returnsNormally,
    );
  });
}
