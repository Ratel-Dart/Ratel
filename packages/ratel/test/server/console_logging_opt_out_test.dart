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
  test('logToConsole: false prints nothing but still logs the record',
      () async {
    final printed = StringBuffer();
    final defaultConsole = RatelLogger.console;
    RatelLogger.console = ConsoleLogHandler(out: printed, err: printed);
    addTearDown(() => RatelLogger.console = defaultConsole);
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    final server = RatelServer(
      port: 0,
      logToConsole: false,
      registry: RatelRegistry.fromManifest(
        const RatelManifest(controllers: [BoomControllerDefinition.value]),
      ),
    );
    await server.startServer();
    addTearDown(() => server.stop(force: true));

    final (status, _) = await HttpProbe(server.boundPort!).send('GET', '/boom');

    expect(status, HttpStatus.internalServerError);
    expect(printed.toString(), isEmpty);
    expect(records.where((record) => record.level == Level.SEVERE), isNotEmpty);
  });
}
