final class NameAllocator {
  final Set<String> _used = {};

  String allocate(List<String> words) {
    final base = '_${_camel(words)}';
    var name = base;
    var suffix = 2;
    while (!_used.add(name)) {
      name = '$base$suffix';
      suffix++;
    }
    return name;
  }

  static String _camel(List<String> words) {
    final buffer = StringBuffer();
    for (final word in words.where((word) => word.isNotEmpty)) {
      final head =
          buffer.isEmpty ? word[0].toLowerCase() : word[0].toUpperCase();
      buffer
        ..write(head)
        ..write(word.substring(1));
    }
    return buffer.toString();
  }
}
