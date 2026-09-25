abstract final class Utf8ContentType {
  static const _charset = ' charset=utf-8';

  static String forText(String contentType) {
    final segments = contentType.split(';');
    final charset = segments.indexWhere(_isCharset, 1);
    if (charset == -1) return forBytes(contentType);
    final parameters = segments
        .skip(1)
        .where((segment) => !_isCharset(segment))
        .toList()
      ..insert(charset - 1, _charset);
    return _join(segments.first, parameters);
  }

  static String forBytes(String contentType) {
    final segments = contentType.split(';');
    if (segments.skip(1).any(_isCharset) || !_isTextual(segments.first)) {
      return contentType;
    }
    return _join(segments.first, [...segments.skip(1), _charset]);
  }

  static String _join(String mimeType, Iterable<String> parameters) => [
        mimeType.trim(),
        ...parameters.where((parameter) => parameter.trim().isNotEmpty),
      ].join(';');

  static bool _isCharset(String parameter) {
    final equals = parameter.indexOf('=');
    return equals != -1 &&
        parameter.substring(0, equals).trim().toLowerCase() == 'charset';
  }

  static bool _isTextual(String mimeType) {
    final type = mimeType.trim().toLowerCase();
    return type.startsWith('text/') ||
        type == 'application/json' ||
        type.endsWith('+json');
  }
}
