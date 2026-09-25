import 'dart:io';

import '../exceptions/bad_request_exception.dart';

abstract final class RequestParameters {
  static String? cookieValue(List<Cookie> cookies, String name) {
    for (final cookie in cookies) {
      if (cookie.name == name) return cookie.value;
    }
    return null;
  }

  static String? queryValue(Uri uri, String name) {
    try {
      return uri.queryParameters[name];
    } on FormatException {
      throw const BadRequestException('Malformed query string');
    }
  }

  static Object? coerce(String name, String? value, Type targetType) {
    if (value == null) return null;
    if (targetType == int) {
      final parsed = int.tryParse(value);
      if (parsed == null) {
        throw BadRequestException('Parameter "$name" must be an integer');
      }
      return parsed;
    }
    if (targetType == double) {
      final parsed = double.tryParse(value);
      if (parsed == null) {
        throw BadRequestException('Parameter "$name" must be a number');
      }
      return parsed;
    }
    if (targetType == bool) {
      return value.toLowerCase() == 'true';
    }
    return value;
  }
}
