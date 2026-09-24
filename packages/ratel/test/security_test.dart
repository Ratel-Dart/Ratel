import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel/src/http/request_body_reader.dart';
import 'package:ratel/src/http/request_parameters.dart';
import 'package:test/test.dart';

void main() {
  group('RequestParameters.coerce', () {
    test('parses a valid integer', () {
      expect(RequestParameters.coerce('id', '42', int), 42);
    });

    test('rejects a non-integer with BadRequestException', () {
      expect(
        () => RequestParameters.coerce('id', 'abc', int),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('parses a valid double', () {
      expect(RequestParameters.coerce('x', '3.5', double), 3.5);
    });

    test('rejects a non-number double with BadRequestException', () {
      expect(
        () => RequestParameters.coerce('x', 'abc', double),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('parses bool true/false case-insensitively', () {
      expect(RequestParameters.coerce('f', 'true', bool), isTrue);
      expect(RequestParameters.coerce('f', 'FALSE', bool), isFalse);
    });

    test('passes strings through unchanged', () {
      expect(RequestParameters.coerce('q', 'hello', String), 'hello');
    });
  });

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

  group('JwtAuthMiddleware.validateToken', () {
    final middleware = JwtAuthMiddleware('secret');

    String token({Duration? expiresIn}) =>
        JWT({'sub': 'user-1'}).sign(SecretKey('secret'), expiresIn: expiresIn);

    test('accepts a valid token carrying exp', () {
      final claims =
          middleware.validateToken(token(expiresIn: Duration(hours: 1)));
      expect(claims, isNotNull);
      expect(claims!['sub'], 'user-1');
    });

    test('rejects a token without exp when expiry is required', () {
      expect(middleware.validateToken(token()), isNull);
    });

    test('rejects an expired token', () {
      expect(
        middleware.validateToken(token(expiresIn: Duration(seconds: -10))),
        isNull,
      );
    });

    test('rejects a token signed with a different secret', () {
      final other = JWT({'sub': 'x'})
          .sign(SecretKey('wrong'), expiresIn: Duration(hours: 1));
      expect(middleware.validateToken(other), isNull);
    });

    test('accepts a token without exp when requireExpiry is false', () {
      final lenient = JwtAuthMiddleware('secret', requireExpiry: false);
      expect(lenient.validateToken(token()), isNotNull);
    });
  });
}
