import '../exceptions/bad_request_exception.dart';

abstract final class RoutePath {
  static List<String> split(String path) {
    var normalized = path;
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) return const [];
    return normalized.split('/');
  }

  static List<String> decode(String path) {
    try {
      return split(path).map(Uri.decodeComponent).toList(growable: false);
    } on FormatException {
      throw const BadRequestException(_malformed);
    } on ArgumentError {
      throw const BadRequestException(_malformed);
    }
  }

  static String decodeLiteral(String segment) {
    try {
      return Uri.decodeComponent(segment);
    } on FormatException {
      return segment;
    } on ArgumentError {
      return segment;
    }
  }

  static String normalize(String path) => '/${split(path).join('/')}';

  static const _malformed = 'Malformed percent-encoding in the request path';
}
