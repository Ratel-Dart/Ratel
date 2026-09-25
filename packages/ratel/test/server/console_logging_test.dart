import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:ratel/src/logging/console_log_handler.dart';
import 'package:ratel/src/logging/ratel_logger.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/boom_controller_definition.dart';
import '../support/http_probe.dart';

void main() {
  const manifest = RatelManifest(controllers: [BoomControllerDefinition.value]);
  final first = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(manifest),
  );
  final second = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(manifest),
  );
  final printed = StringBuffer();
  final defaultConsole = RatelLogger.console;

  setUpAll(() async {
    RatelLogger.console = ConsoleLogHandler(out: printed, err: printed);
    await first.startServer();
    await second.startServer();
  });

  tearDownAll(() async {
    await first.stop(force: true);
    await second.stop(force: true);
    RatelLogger.console = defaultConsole;
  });

  setUp(printed.clear);

  Future<String> boomOn(RatelServer server) async {
    final (status, body) =
        await HttpProbe(server.boundPort!).send('GET', '/boom');
    expect(status, HttpStatus.internalServerError);
    return (jsonDecode(body) as Map<String, dynamic>)['correlationId']
        as String;
  }

  test('a 500 prints its correlation id, error and stack trace', () async {
    final correlationId = await boomOn(first);

    final lines = printed.toString().split('\n');
    expect(
      lines.first,
      endsWith(' SEVERE ratel: Unhandled error [$correlationId] GET /boom'),
    );
    expect(lines[1], 'Bad state: kaboom');
    expect(lines.skip(2).join('\n'), contains('BoomController.boom'));
  });

  test('two servers print each record once', () async {
    final correlationId = await boomOn(second);

    expect(
      '[$correlationId]'.allMatches(printed.toString()),
      hasLength(1),
    );
  });

  test('records of other loggers are not printed', () {
    Logger('app').severe('not a ratel record');

    expect(printed.toString(), isEmpty);
  });

  test('an error whose toString throws still answers 500 and prints its line',
      () async {
    final (status, body) =
        await HttpProbe(first.boundPort!).send('GET', '/unprintable');

    expect(status, HttpStatus.internalServerError);
    final correlationId =
        (jsonDecode(body) as Map<String, dynamic>)['correlationId'] as String;
    final lines = printed.toString().split('\n');
    expect(
      lines.first,
      endsWith(
        ' SEVERE ratel: Unhandled error [$correlationId] GET /unprintable',
      ),
    );
    expect(lines[1], "Instance of 'UnprintableFailure'");
  });
}
