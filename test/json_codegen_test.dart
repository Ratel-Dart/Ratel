import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

part 'json_codegen_test.g.dart';

@Json()
class Point {
  int x;
  int y;

  Point(this.x, this.y);

  Map<String, dynamic> toJson() => _$PointToJson(this);
}

class _Plain {
  @override
  String toString() => 'plain-value';
}

void main() {
  test('serializes a @Json object via generated toJson (no mirrors)', () {
    final response =
        Response.json(statusCode: HttpStatus.ok, data: Point(1, 2));
    expect(response.toJson(), '{"x":1,"y":2}');
  });

  test('serializes a list of @Json objects', () {
    final response = Response.json(
      statusCode: HttpStatus.ok,
      data: [Point(1, 2), Point(3, 4)],
    );
    expect(response.toJson(), '[{"x":1,"y":2},{"x":3,"y":4}]');
  });

  test('falls back to toString for objects without toJson', () {
    final response = Response.json(statusCode: HttpStatus.ok, data: _Plain());
    expect(response.toJson(), '"plain-value"');
  });
}
