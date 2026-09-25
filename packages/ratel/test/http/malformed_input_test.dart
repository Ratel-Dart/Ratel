import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/seat_codec.dart';
import '../support/fixtures/codecs/ticket_codec.dart';
import '../support/fixtures/definitions/multipart_upload_controller_definition.dart';
import '../support/fixtures/definitions/strict_input_controller_definition.dart';
import '../support/http_probe.dart';

void main() {
  late RatelServer server;
  late HttpProbe probe;
  final records = <LogRecord>[];

  setUpAll(() async {
    server = RatelServer(
      port: 0,
      registry: RatelRegistry.fromManifest(
        const RatelManifest(
          controllers: [
            StrictInputControllerDefinition.value,
            MultipartUploadControllerDefinition.value,
          ],
          jsonCodecs: [TicketCodec.definition, SeatCodec.definition],
        ),
      ),
    );
    await server.startServer();
    probe = HttpProbe(server.boundPort!);
  });

  tearDownAll(() => server.stop(force: true));

  setUp(() {
    records.clear();
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
  });

  Future<(int, String)> send(
    String method,
    String path, {
    String? contentType,
    List<int>? body,
  }) =>
      probe
          .send(
            method,
            path,
            headers: {if (contentType != null) 'content-type': contentType},
            body: body,
          )
          .timeout(const Duration(seconds: 5));

  void expectRejected((int, String) response, String message) {
    final (status, body) = response;
    expect(status, HttpStatus.badRequest);
    expect(jsonDecode(body), {'error': message});
    expect(
      records.where((record) => record.level >= Level.SEVERE),
      isEmpty,
    );
  }

  List<int> multipart(List<String> lines) =>
      utf8.encode(lines.map((line) => '$line\r\n').join());

  group('a JSON body', () {
    test('answers 400 when it is not valid UTF-8', () async {
      expectRejected(
        await send(
          'POST',
          '/seats',
          contentType: 'application/json',
          body: [...utf8.encode('{"row":3,"label":"'), 0xff, 0x22, 0x7d],
        ),
        'Request body is not valid UTF-8',
      );
    });
  });

  group('a form body', () {
    const form = 'application/x-www-form-urlencoded';

    test('answers 400 when it is not valid UTF-8', () async {
      expectRejected(
        await send(
          'POST',
          '/seats',
          contentType: form,
          body: [...utf8.encode('row=3&label='), 0xc3, 0x28],
        ),
        'Request body is not valid UTF-8',
      );
    });

    test('answers 400 on a bad percent-escape', () async {
      expectRejected(
        await send(
          'POST',
          '/seats',
          contentType: form,
          body: utf8.encode('row=3&label=%zz'),
        ),
        'Malformed form body',
      );
    });

    test('answers 400 on a truncated percent-escape', () async {
      expectRejected(
        await send(
          'POST',
          '/seats',
          contentType: form,
          body: utf8.encode('row=3&label=%F'),
        ),
        'Malformed form body',
      );
    });

    test('answers 400 on a percent-escape that is not UTF-8', () async {
      expectRejected(
        await send(
          'POST',
          '/seats',
          contentType: form,
          body: utf8.encode('row=3&label=%FF'),
        ),
        'Malformed form body',
      );
    });
  });

  group('a multipart body', () {
    const multipartType = 'multipart/form-data; boundary=RATEL';

    test('answers 400 when the closing boundary is missing', () async {
      expectRejected(
        await send(
          'POST',
          '/upload',
          contentType: multipartType,
          body: multipart([
            '--RATEL',
            'content-disposition: form-data; name="title"',
            '',
            'hello',
          ]),
        ),
        'Malformed multipart body',
      );
    });

    test('answers 400 on a garbled part header', () async {
      expectRejected(
        await send(
          'POST',
          '/upload',
          contentType: multipartType,
          body: multipart([
            '--RATEL',
            'not a header',
            '',
            'hello',
            '--RATEL--',
          ]),
        ),
        'Malformed multipart body',
      );
    });

    test('answers 400 on a garbled boundary line', () async {
      expectRejected(
        await send(
          'POST',
          '/upload',
          contentType: multipartType,
          body: multipart([
            '--RATEL?',
            'content-disposition: form-data; name="title"',
            '',
            'hello',
            '--RATEL--',
          ]),
        ),
        'Malformed multipart body',
      );
    });

    test('answers 400 when a field is not valid UTF-8', () async {
      expectRejected(
        await send(
          'POST',
          '/upload',
          contentType: multipartType,
          body: [
            ...multipart([
              '--RATEL',
              'content-disposition: form-data; name="title"',
              '',
            ]),
            0xc3,
            0x28,
            ...multipart(['', '--RATEL--']),
          ],
        ),
        'Malformed multipart body',
      );
    });

    test('answers 400 when it is decoded into a DTO', () async {
      expectRejected(
        await send(
          'POST',
          '/seats',
          contentType: multipartType,
          body: multipart([
            '--RATEL',
            'content-disposition: form-data; name="row"',
            '',
            '3',
          ]),
        ),
        'Malformed multipart body',
      );
    });
  });

  group('a query string', () {
    test('answers 400 on a percent-escape that is not UTF-8', () async {
      expectRejected(
        await send('GET', '/search?q=%FF'),
        'Malformed query string',
      );
    });

    test('still binds a well-formed parameter', () async {
      final (status, body) = await send('GET', '/search?q=a%20b');
      expect(status, HttpStatus.ok);
      expect(jsonDecode(body), {'q': 'a b'});
    });
  });
}
