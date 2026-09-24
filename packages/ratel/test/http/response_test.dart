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
  });

  group('Response.from', () {
    test('wraps a plain value as a 200 JSON response', () {
      final r = Response.from({'ok': true});
      expect(r.statusCode, HttpStatus.ok);
      expect(r.contentType, 'application/json');
      expect(r.toJson(), '{"ok":true}');
    });

    test('returns the same Response instance when given one', () {
      final original = Response.text(statusCode: 201, data: 'hi');
      expect(identical(Response.from(original), original), isTrue);
    });
  });
}
