abstract final class SqlNames {
  static final _digit = RegExp('[0-9]');

  static String of(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final char = name[i];
      if (_isUpper(char) && i > 0) {
        final previous = name[i - 1];
        final next = i + 1 < name.length ? name[i + 1] : '';
        if (_isLower(previous) ||
            _digit.hasMatch(previous) ||
            (_isUpper(previous) && next.isNotEmpty && _isLower(next))) {
          buffer.write('_');
        }
      }
      buffer.write(char.toLowerCase());
    }
    return '$buffer';
  }

  static bool _isUpper(String char) =>
      char.toUpperCase() == char && char.toLowerCase() != char;

  static bool _isLower(String char) =>
      char.toLowerCase() == char && char.toUpperCase() != char;
}
