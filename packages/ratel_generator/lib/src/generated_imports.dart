class GeneratedImports {
  final Map<String, String> _prefixes = {};

  Iterable<MapEntry<String, String>> get entries => _prefixes.entries;

  String prefixFor(String uri) =>
      _prefixes.putIfAbsent(uri, () => '_m${_prefixes.length}');
}
