import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/ticket_codec.dart';
import '../support/fixtures/definitions/strict_input_controller_definition.dart';
import '../support/http_probe.dart';

void main() {
  late RatelServer server;
  late HttpProbe probe;

  setUpAll(() async {
    server = RatelServer(
      port: 0,
      registry: RatelRegistry.fromManifest(
        const RatelManifest(
          controllers: [StrictInputControllerDefinition.value],
          jsonCodecs: [TicketCodec.definition],
        ),
      ),
    );
    await server.startServer();
    probe = HttpProbe(server.boundPort!);
  });

  tearDownAll(() => server.stop(force: true));

  group('a missing required parameter', () {
    test('answers 400 naming a query parameter', () async {
      final (status, body) = await probe.send('GET', '/search');
      expect(status, 400);
      expect(jsonDecode(body)['error'], contains('"q"'));
    });

    test('answers 400 naming a header parameter', () async {
      final (status, body) = await probe.send('GET', '/traced');
      expect(status, 400);
      expect(jsonDecode(body)['error'], contains('"X-Trace"'));
    });

    test('answers 400 naming a cookie parameter', () async {
      final (status, body) = await probe.send('GET', '/session');
      expect(status, 400);
      expect(jsonDecode(body)['error'], contains('"session"'));
    });

    test('still binds the parameter when it is present', () async {
      final (status, body) = await probe.send(
        'GET',
        '/session',
        cookies: [Cookie('session', 's1')],
      );
      expect(status, 200);
      expect(jsonDecode(body), {'session': 's1'});
    });
  });

  group('a JSON body', () {
    test('answers 400 naming the body type when a field has the wrong type',
        () async {
      final (status, body) = await probe.send(
        'POST',
        '/tickets',
        headers: {'content-type': 'application/json'},
        body: utf8.encode('{"id":"x"}'),
      );
      expect(status, 400);
      expect(jsonDecode(body)['error'], contains('Ticket'));
    });

    test('decodes when the field types match', () async {
      final (status, body) = await probe.send(
        'POST',
        '/tickets',
        headers: {'content-type': 'application/json'},
        body: utf8.encode('{"id":3}'),
      );
      expect(status, 200);
      expect(jsonDecode(body), {'id': 3});
    });
  });
}
