import 'dart:convert';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'json_codegen_test.ratel.dart';

@Json()
class Point {
  int x;
  int y;

  Point(this.x, this.y);
}

enum Status { active, archived }

class Plain {
  @override
  String toString() => 'plain-value';
}

class HandWritten {
  Map<String, dynamic> toJson() => {'kind': 'hand-written'};
}

void main() {
  setUpAll(() {
    RatelJson.reset();
    $registerRatel();
  });

  test('serializes a @Json object via its generated encoder', () {
    expect(Response.json(data: Point(1, 2)).toJson(), '{"x":1,"y":2}');
  });

  test('serializes a list of @Json objects', () {
    expect(
      Response.json(data: [Point(1, 2), Point(3, 4)]).toJson(),
      '[{"x":1,"y":2},{"x":3,"y":4}]',
    );
  });

  test('serializes a DateTime as an ISO-8601 string', () {
    final response = Response.json(data: {'at': DateTime.utc(2026, 7, 13)});
    expect(response.toJson(), '{"at":"2026-07-13T00:00:00.000Z"}');
  });

  test('serializes an enum as its name', () {
    expect(
      Response.json(data: {'status': Status.archived}).toJson(),
      '{"status":"archived"}',
    );
  });

  test('serializes Uri and BigInt as strings', () {
    final response = Response.json(data: {
      'uri': Uri.parse('https://example.com/a'),
      'big': BigInt.from(2).pow(64),
    });
    expect(
      response.toJson(),
      '{"uri":"https://example.com/a","big":"18446744073709551616"}',
    );
  });

  test('still honours a hand-written toJson', () {
    expect(
      Response.json(data: HandWritten()).toJson(),
      '{"kind":"hand-written"}',
    );
  });

  test('throws naming the type when an object has no encoder', () {
    expect(
      () => Response.json(data: Plain()).toJson(),
      throwsA(
        isA<JsonUnsupportedObjectError>()
            .having((e) => e.cause, 'cause', isA<RatelSerializationException>())
            .having((e) => e.toString(), 'message', contains('Plain')),
      ),
    );
  });
}
