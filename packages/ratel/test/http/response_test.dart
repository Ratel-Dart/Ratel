import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  group('Response.toJson', () {
    test('encodes a Map as JSON', () {
      final r = Response.json(statusCode: 200, data: {'a': 1});
      expect(r.toJson(), '{"a":1}');
    });

    test('encodes a List as JSON', () {
      final r = Response.json(statusCode: 200, data: [1, 2, 3]);
      expect(r.toJson(), '[1,2,3]');
    });

    test('passes a String body through unchanged', () {
      final r = Response.json(statusCode: 200, data: 'hello');
      expect(r.toJson(), 'hello');
    });

    test('returns an empty string for null data', () {
      final r = Response.json(statusCode: 200, data: null);
      expect(r.toJson(), '');
    });

    test('encodes JSON when the content type carries parameters', () {
      final r = Response(
        statusCode: 200,
        data: {'a': 1},
        contentType: 'application/json; charset=utf-8',
      );
      expect(r.toJson(), '{"a":1}');
    });
  });

  group('Response.from', () {
    test('wraps a plain value as a 200 JSON response', () {
      final r = Response.from({'ok': true});
      expect(r.statusCode, HttpStatus.ok);
      expect(r.contentType, 'application/json; charset=utf-8');
      expect(r.toJson(), '{"ok":true}');
    });

    test('returns the same Response instance when given one', () {
      final original = Response.text(statusCode: 201, data: 'hi');
      expect(identical(Response.from(original), original), isTrue);
    });

    test('passes a typed Response through unchanged', () {
      final typed = Response<List<int>>.json(statusCode: 201, data: [1]);
      expect(identical(Response.from(typed), typed), isTrue);
    });
  });

  group('Response<T>', () {
    test('types its payload', () {
      final Response<List<int>> typed = Response.json(data: [1, 2]);
      final List<int>? data = typed.data;
      expect(data, [1, 2]);
    });

    test('keeps the payload type through withHeaders and withCookie', () {
      final Response<List<int>> decorated =
          Response<List<int>>.json(statusCode: 201, data: [1, 2])
              .withHeaders({'x-trace': '1'}).withCookie(Cookie('s', 'v'));
      expect(decorated.data, [1, 2]);
      expect(decorated.statusCode, 201);
      expect(decorated.headers['x-trace'], '1');
      expect(decorated.cookies.single.name, 's');
    });

    test('is assignable to a raw Response', () {
      final Response raw = Response<String>.text(data: 'hi');
      expect(raw.toJson(), 'hi');
    });
  });
}
