import 'package:ratel/ratel.dart';
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
}
