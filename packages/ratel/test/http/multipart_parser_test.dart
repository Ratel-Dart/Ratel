import 'dart:async';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/src/http/multipart_parser.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late HttpClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<Object?> parse(int contentBytes, {required int maxDrainBytes}) {
    final outcome = Completer<Object?>();
    server.listen((request) async {
      try {
        outcome.complete(
          await MultipartParser.read(
            request,
            4,
            maxDrainBytes: maxDrainBytes,
          ),
        );
      } catch (error) {
        outcome.complete(error);
      }
      await request.response.close().catchError((_) {});
    });
    unawaited(() async {
      final req = await client.post('127.0.0.1', server.port, '/');
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=RATEL',
      );
      req.write(
        '--RATEL\r\ncontent-disposition: form-data; name="big"\r\n\r\n'
        '${'x' * contentBytes}\r\n--RATEL--\r\n',
      );
      await (await req.close()).drain<void>();
    }()
        .catchError((_) {}));
    return outcome.future;
  }

  test('drains a body over the limit before answering 413', () async {
    expect(
      await parse(64 * 1024, maxDrainBytes: RequestLimits.defaultBytes),
      isA<PayloadTooLargeException>()
          .having((e) => e.headers, 'headers', isEmpty),
    );
  });

  test('closes the connection when the drain limit is passed', () async {
    expect(
      await parse(64 * 1024, maxDrainBytes: 8),
      isA<PayloadTooLargeException>().having(
        (e) => e.headers,
        'headers',
        {HttpHeaders.connectionHeader: 'close'},
      ),
    );
  });
}
