import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  const samples = ['São Paulo', '日本', 'ratel 🦡'];
  const limit = Duration(seconds: 5);
  final client = HttpClient();
  late HttpServer server;
  late Response Function() respond;
  late Completer<Object?> sent;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await respond().send(request.response);
        sent.complete(null);
      } catch (error) {
        sent.complete(error);
      }
    });
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<(String?, List<int>, Object?)> fetch(
    Response Function() build,
  ) async {
    respond = build;
    sent = Completer<Object?>();
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/'),
    );
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );
    return (
      response.headers.value(HttpHeaders.contentTypeHeader),
      bytes,
      await sent.future,
    );
  }

  for (final sample in samples) {
    group('"$sample"', () {
      test('Response.json sends UTF-8 JSON', () async {
        final (type, bytes, _) = await fetch(
          () => Response.json(data: {'city': sample}),
        ).timeout(limit);
        expect(bytes, utf8.encode(jsonEncode({'city': sample})));
        expect(type, 'application/json; charset=utf-8');
        expect(jsonDecode(utf8.decode(bytes)), {'city': sample});
      });

      test('Response.text sends UTF-8 text', () async {
        final (type, bytes, _) = await fetch(
          () => Response.text(data: sample),
        ).timeout(limit);
        expect(type, 'text/plain; charset=utf-8');
        expect(utf8.decode(bytes), sample);
      });

      test('Response.html sends UTF-8 HTML', () async {
        final (type, bytes, _) = await fetch(
          () => Response.html(data: '<p>$sample</p>'),
        ).timeout(limit);
        expect(type, 'text/html; charset=utf-8');
        expect(utf8.decode(bytes), '<p>$sample</p>');
      });

      test('Response.sse sends UTF-8 frames', () async {
        final (type, bytes, _) = await fetch(
          () => Response.sse(Stream.value(sample)),
        ).timeout(limit);
        expect(type, 'text/event-stream; charset=utf-8');
        expect(utf8.decode(bytes), ':\n\ndata: $sample\n\n');
      });
    });
  }

  group('content type', () {
    test('defaults to UTF-8 JSON', () async {
      final (type, bytes, _) = await fetch(
        () => Response(statusCode: HttpStatus.ok, data: {'city': '日本'}),
      ).timeout(limit);
      expect(type, 'application/json; charset=utf-8');
      expect(jsonDecode(utf8.decode(bytes)), {'city': '日本'});
    });

    test('gains charset=utf-8 on a custom text type', () async {
      final (type, bytes, _) = await fetch(
        () => Response.text(
          data: 'São Paulo',
          headers: const {'Content-Type': 'text/csv'},
        ),
      ).timeout(limit);
      expect(type, 'text/csv; charset=utf-8');
      expect(utf8.decode(bytes), 'São Paulo');
    });

    test('gains charset=utf-8 on a +json type', () async {
      final (type, bytes, _) = await fetch(
        () => Response(
          statusCode: HttpStatus.ok,
          data: '{"title":"日本"}',
          contentType: 'application/problem+json',
          headers: const {},
        ),
      ).timeout(limit);
      expect(type, 'application/problem+json; charset=utf-8');
      expect(utf8.decode(bytes), '{"title":"日本"}');
    });

    test('keeps the other parameters of the type', () async {
      final (type, _, _) = await fetch(
        () => Response(
          statusCode: HttpStatus.ok,
          data: 'a',
          contentType: 'text/plain; format=flowed',
          headers: const {},
        ),
      ).timeout(limit);
      expect(type, 'text/plain; format=flowed; charset=utf-8');
    });

    test('does not repeat a charset=utf-8 already given', () async {
      final (type, bytes, _) = await fetch(
        () => Response(
          statusCode: HttpStatus.ok,
          data: {'city': 'São Paulo'},
          contentType: 'application/json; charset=utf-8',
          headers: const {},
        ),
      ).timeout(limit);
      expect(type, 'application/json; charset=utf-8');
      expect(jsonDecode(utf8.decode(bytes)), {'city': 'São Paulo'});
    });

    test('labels a string body as UTF-8 over another charset', () async {
      final (type, bytes, _) = await fetch(
        () => Response(
          statusCode: HttpStatus.ok,
          data: 'São Paulo',
          contentType: 'text/plain; charset=iso-8859-1',
          headers: const {},
        ),
      ).timeout(limit);
      expect(type, 'text/plain; charset=utf-8');
      expect(utf8.decode(bytes), 'São Paulo');
    });

    test('keeps the charset given with a byte body', () async {
      final (type, bytes, _) = await fetch(
        () => Response.bytes(
          data: latin1.encode('São Paulo'),
          headers: const {'content-type': 'text/plain; charset=iso-8859-1'},
        ),
      ).timeout(limit);
      expect(type, 'text/plain; charset=iso-8859-1');
      expect(latin1.decode(bytes), 'São Paulo');
    });

    test('gains charset=utf-8 on a text byte body', () async {
      final (type, bytes, _) = await fetch(
        () => Response.bytes(
          data: utf8.encode('日本'),
          headers: const {'content-type': 'text/plain'},
        ),
      ).timeout(limit);
      expect(type, 'text/plain; charset=utf-8');
      expect(utf8.decode(bytes), '日本');
    });

    test('leaves a binary type alone', () async {
      final (type, bytes, _) = await fetch(
        () => Response.bytes(data: const [0, 1, 2]),
      ).timeout(limit);
      expect(type, 'application/octet-stream');
      expect(bytes, [0, 1, 2]);
    });
  });

  group('failure', () {
    test('an event stream that fails still closes the response', () async {
      final (_, bytes, failure) = await fetch(
        () => Response.sse(
          Stream<String>.multi((events) {
            events
              ..add('tick')
              ..addError(StateError('lost the feed'));
          }),
        ),
      ).timeout(limit);
      expect(utf8.decode(bytes), ':\n\ndata: tick\n\n');
      expect(failure, isA<StateError>());
    });

    test('a header that cannot be written still closes the response', () async {
      final (_, bytes, failure) = await fetch(
        () => Response.text(
          data: 'São Paulo',
          headers: const {'bad header': 'value'},
        ),
      ).timeout(limit);
      expect(bytes, isEmpty);
      expect(failure, isA<FormatException>());
    });

    test('a lone surrogate is sent as a replacement character', () async {
      final (type, bytes, failure) = await fetch(
        () => Response.text(data: 'a\uD800b'),
      ).timeout(limit);
      expect(type, 'text/plain; charset=utf-8');
      expect(utf8.decode(bytes), 'a\uFFFDb');
      expect(failure, isNull);
    });
  });
}
