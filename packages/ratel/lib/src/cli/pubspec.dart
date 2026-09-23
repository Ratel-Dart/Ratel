/// Reads the fields the CLI needs out of raw `pubspec.yaml` text.
///
/// Deliberately regex-based rather than a YAML parse: the CLI reads three
/// scalars and should not pull a parser into the framework's dependencies.
library;

final _namePattern = RegExp(r'^name:\s*(\S+)\s*$', multiLine: true);
final _versionPattern = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);

/// The `name:` declared in [pubspec], or null when absent.
String? readName(String pubspec) => _namePattern.firstMatch(pubspec)?.group(1);

/// The `version:` declared in [pubspec], or null when absent.
String? readVersion(String pubspec) =>
    _versionPattern.firstMatch(pubspec)?.group(1);

/// Whether [pubspec] declares [name] as a dependency.
///
/// Matches an indented `name:` key rather than the bare word, so a mention in
/// a description or a comment does not count as a declaration.
bool declaresDependency(String pubspec, String name) =>
    RegExp(r'^\s+' + RegExp.escape(name) + r'\s*:', multiLine: true)
        .hasMatch(pubspec);
