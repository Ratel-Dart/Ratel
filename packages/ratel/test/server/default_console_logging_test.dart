import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('an unhandled 500 prints its correlation id and stack trace to stderr',
      () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['test/support/fixtures/apps/boom_app.dart'],
    ).timeout(const Duration(minutes: 2));

    expect(result.exitCode, 0, reason: '${result.stderr}');
    final body = const LineSplitter().convert('${result.stdout}').last;
    final correlationId = (jsonDecode(body) as Map)['correlationId'] as String;
    final headline = RegExp.escape(
      'SEVERE ratel: Unhandled error [$correlationId] GET /boom',
    );
    final printed = '${result.stderr}';
    expect(
      printed,
      matches(RegExp(
        r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z ' '$headline\$',
        multiLine: true,
      )),
    );
    expect(printed, contains('Bad state: kaboom'));
    expect(printed, contains('boom_controller.dart'));
  });

  test('a stdout nobody reads any more does not stop the server', () async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['test/support/fixtures/apps/closed_console_app.dart'],
    );
    final printed = process.stderr.transform(utf8.decoder).join();
    await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line == 'listening')
        .timeout(const Duration(minutes: 2));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    process.stdin.writeln('go');
    await process.stdin.flush();

    final exitCode = await process.exitCode.timeout(const Duration(minutes: 1));

    expect(exitCode, 0, reason: await printed);
    expect(await printed, contains('still running'));
  });
}
