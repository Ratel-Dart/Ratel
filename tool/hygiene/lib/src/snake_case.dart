abstract final class SnakeCase {
  static String of(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final char = name[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (isUpper && i > 0) {
        final previous = name[i - 1];
        final next = i + 1 < name.length ? name[i + 1] : '';
        final previousLower = previous.toLowerCase() == previous &&
            previous.toUpperCase() != previous;
        final previousDigit = RegExp(r'[0-9]').hasMatch(previous);
        final nextLower = next.isNotEmpty &&
            next.toLowerCase() == next &&
            next.toUpperCase() != next;
        final previousUpper = previous.toUpperCase() == previous &&
            previous.toLowerCase() != previous;
        if (previousLower || previousDigit || (previousUpper && nextLower)) {
          buffer.write('_');
        }
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}
