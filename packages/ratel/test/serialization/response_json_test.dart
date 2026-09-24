import 'dart:convert';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/grid_point_codec.dart';
import '../support/fixtures/models/archive_status.dart';
import '../support/fixtures/models/grid_point.dart';
import '../support/fixtures/models/hand_written_json.dart';
import '../support/fixtures/models/plain_value.dart';

void main() {
  final codecs = JsonCodecs([GridPointCodec.definition]);

  test('serializes an object through its JSON codec', () {
    expect(
      Response.json(data: GridPoint(1, 2)).toJson(codecs: codecs),
      '{"x":1,"y":2}',
    );
  });

  test('serializes a list of codec-backed objects', () {
    expect(
      Response.json(data: [GridPoint(1, 2), GridPoint(3, 4)])
          .toJson(codecs: codecs),
      '[{"x":1,"y":2},{"x":3,"y":4}]',
    );
  });

  test('serializes a DateTime as an ISO-8601 string', () {
    final response = Response.json(data: {'at': DateTime.utc(2026, 7, 13)});
    expect(
        response.toJson(codecs: codecs), '{"at":"2026-07-13T00:00:00.000Z"}');
  });

  test('serializes an enum as its name', () {
    expect(
      Response.json(data: {'status': ArchiveStatus.archived})
          .toJson(codecs: codecs),
      '{"status":"archived"}',
    );
  });

  test('serializes Uri and BigInt as strings', () {
    final response = Response.json(data: {
      'uri': Uri.parse('https://example.com/a'),
      'big': BigInt.from(2).pow(64),
    });
    expect(
      response.toJson(codecs: codecs),
      '{"uri":"https://example.com/a","big":"18446744073709551616"}',
    );
  });

  test('serializes a set and a lazy iterable as JSON arrays', () {
    final response = Response.json(data: {
      'tags': {'a', 'b'},
      'points': {GridPoint(1, 2)},
      'doubled': [1, 2].map((n) => n * 2),
    });
    expect(
      response.toJson(codecs: codecs),
      '{"tags":["a","b"],"points":[{"x":1,"y":2}],"doubled":[2,4]}',
    );
  });

  test('serializes a set payload as a JSON array', () {
    expect(Response.json(data: {'a', 'b'}).toJson(), '["a","b"]');
  });

  test('still honours a hand-written toJson', () {
    expect(
      Response.json(data: HandWrittenJson()).toJson(codecs: codecs),
      '{"kind":"hand-written"}',
    );
  });

  test('throws naming the type when an object has no encoder', () {
    expect(
      () => Response.json(data: PlainValue()).toJson(codecs: codecs),
      throwsA(
        isA<JsonUnsupportedObjectError>()
            .having((e) => e.cause, 'cause', isA<RatelSerializationException>())
            .having((e) => e.toString(), 'message', contains('PlainValue')),
      ),
    );
  });

  test('explains that route signatures declare the encoders', () {
    expect(
      const RatelSerializationException(PlainValue).toString(),
      'RatelSerializationException: No JSON encoder for PlainValue. Ratel '
      'generates encoders for the types that route signatures declare: '
      'return PlainValue or Response<PlainValue> from a route, or reach it '
      'through a field of such a type. A raw Response hides its payload '
      'type, and the encoder is chosen by the exact runtime class.',
    );
  });
}
