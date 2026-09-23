import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  group('coerceParam', () {
    test('parses a valid integer', () {
      expect(coerceParam('id', '42', int), 42);
    });

    test('rejects a non-integer with BadRequestException', () {
      expect(
        () => coerceParam('id', 'abc', int),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('parses a valid double', () {
      expect(coerceParam('x', '3.5', double), 3.5);
    });

    test('rejects a non-number double with BadRequestException', () {
      expect(
        () => coerceParam('x', 'abc', double),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('parses bool true/false case-insensitively', () {
      expect(coerceParam('f', 'true', bool), isTrue);
      expect(coerceParam('f', 'FALSE', bool), isFalse);
    });

    test('passes strings through unchanged', () {
      expect(coerceParam('q', 'hello', String), 'hello');
    });
  });

  group('readBodyLimited', () {
    test('returns the decoded body when within the limit', () async {
      final stream = Stream<List<int>>.fromIterable([utf8.encode('hello')]);
      expect(await readBodyLimited(stream, 1024), 'hello');
    });

    test('throws PayloadTooLargeException when over the limit', () async {
      final stream = Stream<List<int>>.fromIterable([utf8.encode('too big')]);
      await expectLater(
        readBodyLimited(stream, 4),
        throwsA(isA<PayloadTooLargeException>()),
      );
    });
  });

  group('decodeJsonObject', () {
    test('decodes a JSON object', () {
      expect(decodeJsonObject('{"a":1}'), {'a': 1});
    });

    test('rejects invalid JSON with BadRequestException', () {
      expect(
        () => decodeJsonObject('{not json'),
        throwsA(isA<BadRequestException>()),
      );
    });

    test('rejects a top-level JSON array with BadRequestException', () {
      expect(
        () => decodeJsonObject('[1,2,3]'),
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
