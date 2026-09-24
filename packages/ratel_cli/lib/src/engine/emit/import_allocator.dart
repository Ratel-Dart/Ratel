import '../../project/project_runtimes.dart';
import '../analysis/runtime_contract_reader.dart';
import 'import_uris.dart';

final class ImportAllocator {
  ImportAllocator(this._uris, {required ProjectRuntimes runtimes})
      : _runtimes = runtimes;

  final ImportUris _uris;
  final ProjectRuntimes _runtimes;
  final Map<String, String> _prefixes = {};

  static const runtimePrefix = 'r';
  static const runtimeUri = RuntimeContractReader.ratelLibrary;
  static const ormPrefix = 'o';
  static const ormUri = RuntimeContractReader.ormLibrary;

  static Map<String, String> runtimeImports(ProjectRuntimes runtimes) => {
        if (runtimes.framework) runtimeUri: runtimePrefix,
        if (runtimes.orm) ormUri: ormPrefix,
      };

  static List<String> runtimeDirectives(ProjectRuntimes runtimes) => [
        for (final MapEntry(key: uri, value: prefix)
            in runtimeImports(runtimes).entries)
          "import '$uri' as $prefix;",
      ];

  String? prefixFor(Uri library) {
    if (library.toString() == 'dart:core') return null;
    return _prefixes.putIfAbsent(
      _uris.resolve(library),
      () => 'i${_prefixes.length + 1}',
    );
  }

  List<String> directives({Map<String, String?> extra = const {}}) {
    final all = <String, String?>{
      ...runtimeImports(_runtimes),
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
