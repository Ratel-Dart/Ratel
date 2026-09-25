import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/response_body_controller_definition.dart';
import '../support/http_probe.dart';

void main() {
  final server = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(
        controllers: [ResponseBodyControllerDefinition.value],
      ),
    ),
  );
  late HttpProbe probe;

  setUpAll(() async {
    await server.startServer();
    probe = HttpProbe(server.boundPort!);
  });

  tearDownAll(() => server.stop(force: true));

  test('a body that cannot be encoded answers a logged 500', () async {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);

    final (status, body) = await probe
        .send('GET', '/unencodable')
        .timeout(const Duration(seconds: 5));

    expect(status, HttpStatus.internalServerError);
    final payload = jsonDecode(body) as Map<String, dynamic>;
    expect(payload['error'], 'Internal Server Error');
    final correlationId = payload['correlationId'] as String;
    expect(
      records.where(
        (record) =>
            record.level == Level.SEVERE &&
            record.message.contains(correlationId) &&
            record.error is RatelSerializationException,
      ),
      hasLength(1),
    );
  });

  test('a text body that cannot be rendered answers a logged 500', () async {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);

    final (status, body) = await probe
        .send('GET', '/unprintable')
        .timeout(const Duration(seconds: 5));

    expect(status, HttpStatus.internalServerError);
    final payload = jsonDecode(body) as Map<String, dynamic>;
    expect(payload['error'], 'Internal Server Error');
    final correlationId = payload['correlationId'] as String;
    final logged = records.where(
      (record) =>
          record.level == Level.SEVERE &&
          record.message.contains(correlationId),
    );
    expect(logged, hasLength(1));
    expect(
      logged.single.error,
      isA<StateError>().having((e) => e.message, 'message', 'unprintable'),
    );
    expect(
      logged.single.stackTrace.toString(),
      contains('unprintable_value.dart'),
    );
  });
}
