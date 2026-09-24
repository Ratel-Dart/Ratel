abstract final class DartLiteral {
  static String string(String value) {
    final escaped = value
        .replaceAll(r'\', r'\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return "'$escaped'";
  }

  static String strings(List<String> values) =>
      '[${values.map(string).join(', ')}]';
}
