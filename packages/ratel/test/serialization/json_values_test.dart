import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/models/archive_status.dart';

void main() {
  Matcher rejects(String message) => throwsA(
        isA<BadRequestException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', message),
      );

  group('present', () {
    test('returns a non-null value', () {
      expect(JsonValues.present(0, 'n'), 0);
      expect(JsonValues.present(false, 'b'), false);
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.present(null, 'name'),
        rejects('Field "name" is required'),
      );
    });
  });

  group('nonBlank', () {
    test('turns a blank string into null', () {
      expect(JsonValues.nonBlank(''), isNull);
      expect(JsonValues.nonBlank('  '), isNull);
      expect(JsonValues.nonBlank(null), isNull);
    });

    test('keeps any other value', () {
      expect(JsonValues.nonBlank(' a '), ' a ');
      expect(JsonValues.nonBlank(0), 0);
      expect(JsonValues.nonBlank(false), false);
    });
  });

  group('a blank string', () {
    test('counts as a missing value for every non-string scalar', () {
      final readers = <String, Object? Function(Object?)>{
        'integer': (value) => JsonValues.integer(value, 'f'),
        'real': (value) => JsonValues.real(value, 'f'),
        'number': (value) => JsonValues.number(value, 'f'),
        'boolean': (value) => JsonValues.boolean(value, 'f'),
        'dateTime': (value) => JsonValues.dateTime(value, 'f'),
        'bigInt': (value) => JsonValues.bigInt(value, 'f'),
        'enumeration': (value) =>
            JsonValues.enumeration(value, ArchiveStatus.values, 'f'),
      };
      for (final MapEntry(key: name, value: read) in readers.entries) {
        for (final blank in ['', ' ']) {
          expect(
            () => read(blank),
            rejects('Field "f" is required'),
            reason: '$name "$blank"',
          );
        }
      }
    });

    test('stays a value for a string', () {
      expect(JsonValues.string(' ', 'name'), ' ');
    });
  });

  group('object', () {
    test('returns a JSON object', () {
      final json = <String, dynamic>{'a': 1};
      expect(JsonValues.object(json, 'item'), same(json));
    });

    test('accepts a map whose keys are all strings', () {
      expect(JsonValues.object(<Object, Object>{'a': 1}, 'item'), {'a': 1});
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.object(null, 'item'),
        rejects('Field "item" is required'),
      );
    });

    test('rejects a value that is not an object', () {
      expect(
        () => JsonValues.object([1], 'item'),
        rejects('Field "item" must be a JSON object'),
      );
      expect(
        () => JsonValues.object(<Object, Object>{1: 'a'}, 'item'),
        rejects('Field "item" must be a JSON object'),
      );
    });
  });

  group('list', () {
    test('returns a JSON array', () {
      final json = <dynamic>[1, 'a'];
      expect(JsonValues.list(json, 'tags'), same(json));
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.list(null, 'tags'),
        rejects('Field "tags" is required'),
      );
    });

    test('rejects a value that is not an array', () {
      expect(
        () => JsonValues.list({'a': 1}, 'tags'),
        rejects('Field "tags" must be a JSON array'),
      );
      expect(
        () => JsonValues.list('a,b', 'tags'),
        rejects('Field "tags" must be a JSON array'),
      );
    });
  });

  group('string', () {
    test('returns a string', () {
      expect(JsonValues.string('hello', 'name'), 'hello');
      expect(JsonValues.string('', 'name'), '');
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.string(null, 'name'),
        rejects('Field "name" is required'),
      );
    });

    test('rejects a value that is not a string', () {
      expect(
        () => JsonValues.string(3, 'name'),
        rejects('Field "name" must be a string'),
      );
    });
  });

  group('integer', () {
    test('returns an int', () {
      expect(JsonValues.integer(42, 'count'), 42);
      expect(JsonValues.integer(-7, 'count'), -7);
    });

    test('accepts a double without a fractional part', () {
      expect(JsonValues.integer(3.0, 'count'), allOf(isA<int>(), 3));
    });

    test('coerces a numeric string', () {
      expect(JsonValues.integer('3', 'count'), 3);
      expect(JsonValues.integer('-12', 'count'), -12);
      expect(JsonValues.integer('4.0', 'count'), 4);
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.integer(null, 'count'),
        rejects('Field "count" is required'),
      );
    });

    test('rejects a fractional or non-numeric value', () {
      for (final value in [3.5, '3.5', 'three', '0x10', true, 1e300]) {
        expect(
          () => JsonValues.integer(value, 'count'),
          rejects('Field "count" must be an integer'),
          reason: '$value',
        );
      }
    });

    test('rejects a non-finite double', () {
      for (final value in [double.nan, double.infinity, 'NaN', 'Infinity']) {
        expect(
          () => JsonValues.integer(value, 'count'),
          rejects('Field "count" must be an integer'),
          reason: '$value',
        );
      }
    });
  });

  group('real', () {
    test('returns a double', () {
      expect(JsonValues.real(1.5, 'price'), 1.5);
    });

    test('widens an int to a double', () {
      expect(JsonValues.real(2, 'price'), allOf(isA<double>(), 2.0));
    });

    test('coerces a numeric string', () {
      expect(JsonValues.real('1.5', 'price'), 1.5);
      expect(JsonValues.real('2', 'price'), allOf(isA<double>(), 2.0));
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.real(null, 'price'),
        rejects('Field "price" is required'),
      );
    });

    test('rejects a non-numeric value', () {
      for (final value in [
        'cheap',
        'NaN',
        'Infinity',
        false,
        [1]
      ]) {
        expect(
          () => JsonValues.real(value, 'price'),
          rejects('Field "price" must be a number'),
          reason: '$value',
        );
      }
    });
  });

  group('number', () {
    test('keeps an int as an int and a double as a double', () {
      expect(JsonValues.number(2, 'amount'), allOf(isA<int>(), 2));
      expect(JsonValues.number(2.5, 'amount'), allOf(isA<double>(), 2.5));
    });

    test('coerces a numeric string', () {
      expect(JsonValues.number('7', 'amount'), allOf(isA<int>(), 7));
      expect(JsonValues.number('7.25', 'amount'), allOf(isA<double>(), 7.25));
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.number(null, 'amount'),
        rejects('Field "amount" is required'),
      );
    });

    test('rejects a non-numeric value', () {
      for (final value in ['seven', 'NaN', true]) {
        expect(
          () => JsonValues.number(value, 'amount'),
          rejects('Field "amount" must be a number'),
          reason: '$value',
        );
      }
    });
  });

  group('boolean', () {
    test('returns a bool', () {
      expect(JsonValues.boolean(true, 'active'), isTrue);
      expect(JsonValues.boolean(false, 'active'), isFalse);
    });

    test('coerces "true" and "false" in any case', () {
      expect(JsonValues.boolean('true', 'active'), isTrue);
      expect(JsonValues.boolean('TRUE', 'active'), isTrue);
      expect(JsonValues.boolean('False', 'active'), isFalse);
    });

    test('reads the "on" a checked form checkbox sends as true', () {
      expect(JsonValues.boolean('on', 'active'), isTrue);
      expect(JsonValues.boolean('ON', 'active'), isTrue);
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.boolean(null, 'active'),
        rejects('Field "active" is required'),
      );
    });

    test('rejects any other value', () {
      for (final value in ['yes', '1', 'off', 1, 0]) {
        expect(
          () => JsonValues.boolean(value, 'active'),
          rejects('Field "active" must be a boolean'),
          reason: '$value',
        );
      }
    });
  });

  group('dateTime', () {
    test('parses an ISO-8601 string', () {
      expect(
        JsonValues.dateTime('2026-07-13T10:30:00.000Z', 'at'),
        DateTime.utc(2026, 7, 13, 10, 30),
      );
      expect(JsonValues.dateTime('2026-07-13', 'at'), DateTime(2026, 7, 13));
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.dateTime(null, 'at'),
        rejects('Field "at" is required'),
      );
    });

    test('rejects a value that is not an ISO-8601 string', () {
      for (final value in ['yesterday', 1720000000000]) {
        expect(
          () => JsonValues.dateTime(value, 'at'),
          rejects('Field "at" must be an ISO-8601 date-time string'),
          reason: '$value',
        );
      }
    });
  });

  group('uri', () {
    test('parses a URI string', () {
      expect(
        JsonValues.uri('https://example.com/a?b=c', 'link'),
        Uri.parse('https://example.com/a?b=c'),
      );
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.uri(null, 'link'),
        rejects('Field "link" is required'),
      );
    });

    test('rejects a value that is not a URI string', () {
      for (final value in ['http://[::1', 42]) {
        expect(
          () => JsonValues.uri(value, 'link'),
          rejects('Field "link" must be a URI string'),
          reason: '$value',
        );
      }
    });
  });

  group('bigInt', () {
    test('widens an int', () {
      expect(JsonValues.bigInt(42, 'big'), BigInt.from(42));
    });

    test('parses a numeric string beyond the int range', () {
      expect(
        JsonValues.bigInt('18446744073709551616', 'big'),
        BigInt.from(2).pow(64),
      );
      expect(JsonValues.bigInt('-5', 'big'), BigInt.from(-5));
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.bigInt(null, 'big'),
        rejects('Field "big" is required'),
      );
    });

    test('rejects a fractional or non-numeric value', () {
      for (final value in [1.5, 2.0, '1.5', 'big']) {
        expect(
          () => JsonValues.bigInt(value, 'big'),
          rejects('Field "big" must be an integer'),
          reason: '$value',
        );
      }
    });
  });

  group('enumeration', () {
    test('finds a value by its name', () {
      expect(
        JsonValues.enumeration('archived', ArchiveStatus.values, 'status'),
        ArchiveStatus.archived,
      );
    });

    test('rejects null as a missing field', () {
      expect(
        () => JsonValues.enumeration(null, ArchiveStatus.values, 'status'),
        rejects('Field "status" is required'),
      );
    });

    test('rejects an unknown name listing the allowed ones', () {
      for (final value in ['deleted', 'ARCHIVED', 1]) {
        expect(
          () => JsonValues.enumeration(value, ArchiveStatus.values, 'status'),
          rejects('Field "status" must be one of active, archived'),
          reason: '$value',
        );
      }
    });
  });
}
