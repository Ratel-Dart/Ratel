final _namePattern = RegExp(r'^name:\s*(\S+)\s*$', multiLine: true);
final _versionPattern = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);

String? readName(String pubspec) => _namePattern.firstMatch(pubspec)?.group(1);

String? readVersion(String pubspec) =>
    _versionPattern.firstMatch(pubspec)?.group(1);

bool declaresDependency(String pubspec, String name) =>
    RegExp(r'^\s+' + RegExp.escape(name) + r'\s*:', multiLine: true)
        .hasMatch(pubspec);
