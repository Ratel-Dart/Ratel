import '../exceptions/bad_request_exception.dart';

abstract final class JsonValues {
  static const _minInt = -9223372036854775808.0;
  static const _maxIntExclusive = 9223372036854775808.0;

  static Object present(Object? value, String field) {
    if (value == null) {
      throw BadRequestException('Field "$field" is required');
    }
    return value;
  }

  static Object? nonBlank(Object? value) =>
      value is String && value.trim().isEmpty ? null : value;

  static Map<String, Object?> object(Object? value, String field) {
    final json = present(value, field);
    if (json is Map<String, Object?>) return json;
    if (json is Map && json.keys.every((key) => key is String)) {
      return json.cast<String, Object?>();
    }
    return _invalid(field, 'a JSON object');
  }

  static List<Object?> list(Object? value, String field) {
    final json = present(value, field);
    if (json is List<Object?>) return json;
    return _invalid(field, 'a JSON array');
  }

  static String string(Object? value, String field) {
    final json = present(value, field);
    if (json is String) return json;
    return _invalid(field, 'a string');
  }

  static int integer(Object? value, String field) {
    final json = present(nonBlank(value), field);
    final parsed = switch (json) {
      int() => json,
      double() => _whole(json),
      String() =>
        int.tryParse(json, radix: 10) ?? _whole(double.tryParse(json)),
      _ => null,
    };
    return parsed ?? _invalid(field, 'an integer');
  }

  static double real(Object? value, String field) {
    final json = present(nonBlank(value), field);
    final parsed = switch (json) {
      num() => json.toDouble(),
      String() => _finite(double.tryParse(json)),
      _ => null,
    };
    return parsed ?? _invalid(field, 'a number');
  }

  static num number(Object? value, String field) {
    final json = present(nonBlank(value), field);
    final parsed = switch (json) {
      num() => json,
      String() =>
        int.tryParse(json, radix: 10) ?? _finite(double.tryParse(json)),
      _ => null,
    };
    return parsed ?? _invalid(field, 'a number');
  }

  static bool boolean(Object? value, String field) {
    final json = present(nonBlank(value), field);
    final parsed = switch (json) {
      bool() => json,
      String() => switch (json.trim().toLowerCase()) {
          'true' || 'on' => true,
          'false' => false,
          _ => null,
        },
      _ => null,
    };
    return parsed ?? _invalid(field, 'a boolean');
  }

  static DateTime dateTime(Object? value, String field) {
    final json = present(nonBlank(value), field);
    final parsed = json is String ? DateTime.tryParse(json.trim()) : null;
    return parsed ?? _invalid(field, 'an ISO-8601 date-time string');
  }

  static Uri uri(Object? value, String field) {
    final json = present(value, field);
    final parsed = json is String ? Uri.tryParse(json) : null;
    return parsed ?? _invalid(field, 'a URI string');
  }

  static BigInt bigInt(Object? value, String field) {
    final json = present(nonBlank(value), field);
    final parsed = switch (json) {
      int() => BigInt.from(json),
      String() => BigInt.tryParse(json, radix: 10),
      _ => null,
    };
    return parsed ?? _invalid(field, 'an integer');
  }

  static E enumeration<E extends Enum>(
    Object? value,
    List<E> values,
    String field,
  ) {
    final json = present(nonBlank(value), field);
    for (final candidate in values) {
      if (candidate.name == json) return candidate;
    }
    return _invalid(
      field,
      'one of ${values.map((candidate) => candidate.name).join(', ')}',
    );
  }

  static int? _whole(double? value) {
    if (value == null || value != value.truncateToDouble()) return null;
    if (value < _minInt || value >= _maxIntExclusive) return null;
    return value.toInt();
  }

  static double? _finite(double? value) =>
      value != null && value.isFinite ? value : null;

  static Never _invalid(String field, String expected) =>
      throw BadRequestException('Field "$field" must be $expected');
}
