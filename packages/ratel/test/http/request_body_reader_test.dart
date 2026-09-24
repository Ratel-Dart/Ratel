import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/src/http/request_body_reader.dart';
import 'package:test/test.dart';

void main() {
  group('RequestBodyReader.readLimited', () {
    test('returns the decoded body when within the limit', () async {
      final stream = Stream<List<int>>.fromIterable([utf8.encode('hello')]);
      expect(
          await RequestBodyReader.readLimited(
            stream,
            1024,
            maxDrainBytes: RequestLimits.defaultBytes,
          ),
          'hello');
    });

    test('throws PayloadTooLargeException when over the limit', () async {
      final stream = Stream<List<int>>.fromIterable([utf8.encode('too big')]);
      await expectLater(
        RequestBodyReader.readLimited(
          stream,
          4,
          maxDrainBytes: RequestLimits.defaultBytes,
        ),
        throwsA(isA<PayloadTooLargeException>()),
      );
    });

    test('reads past the limit so the request stream is drained', () async {
      var delivered = 0;
      final stream = Stream<List<int>>.fromIterable([
        utf8.encode('a' * 8),
        utf8.encode('b' * 8),
        utf8.encode('c' * 8),
      ]).map((chunk) {
        delivered += chunk.length;
        return chunk;
      });
      await expectLater(
        RequestBodyReader.readLimited(
          stream,
          4,
          maxDrainBytes: RequestLimits.defaultBytes,
        ),
        throwsA(isA<PayloadTooLargeException>()),
      );
      expect(delivered, 24);
    });

    test('closes the connection when the drain limit is passed', () async {
      final stream = Stream<List<int>>.fromIterable([
        utf8.encode('a' * 8),
        utf8.encode('b' * 16),
      ]);
      await expectLater(
        RequestBodyReader.readLimited(stream, 4, maxDrainBytes: 8),
        throwsA(
          isA<PayloadTooLargeException>().having(
            (e) => e.headers,
            'headers',
            {HttpHeaders.connectionHeader: 'close'},
          ),
        ),
      );
    });
  });

  group('RequestBodyReader.decodeJsonObject', () {
    test('decodes a JSON object', () {
      expect(RequestBodyReader.decodeJsonObject('{"a":1}'), {'a': 1});
    });

    test('rejects invalid JSON with BadRequestException', () {
      expect(
        () => RequestBodyReader.decodeJsonObject('{not json'),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('rejects a top-level JSON array with BadRequestException', () {
      expect(
        () => RequestBodyReader.decodeJsonObject('[1,2,3]'),
        throwsA(isA<BadRequestException>()),
      );
    });
  });
}
