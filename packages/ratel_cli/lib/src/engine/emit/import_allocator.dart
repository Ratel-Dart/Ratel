import 'import_uris.dart';

final class ImportAllocator {
  ImportAllocator(this._uris);

  final ImportUris _uris;
  final Map<String, String> _prefixes = {};

  static const runtimePrefix = 'r';
  static const runtimeUri = 'package:ratel/runtime.dart';

  String? prefixFor(Uri library) {
    if (library.toString() == 'dart:core') return null;
    return _prefixes.putIfAbsent(
      _uris.resolve(library),
      () => 'i${_prefixes.length + 1}',
    );
  }

  List<String> directives({Map<String, String?> extra = const {}}) {
    final all = <String, String?>{
      runtimeUri: runtimePrefix,
      ..._prefixes,
      ...extra,
    };
    final groups = <List<String>>[[], [], []];
    final uris = all.keys.toList()..sort();
    for (final uri in uris) {
      final prefix = all[uri];
      final directive =
          prefix == null ? "import '$uri';" : "import '$uri' as $prefix;";
      final group = uri.startsWith('dart:')
          ? 0
          : uri.startsWith('package:')
              ? 1
              : 2;
      groups[group].add(directive);
    }
    return [
      for (final group in groups)
        if (group.isNotEmpty) group.join('\n'),
    ];
  }
}
