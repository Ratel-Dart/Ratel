import 'dart:io';

import 'package:test/test.dart';

/// The CLI hardcodes two version constants: one as a fallback for when it
/// cannot resolve its own pubspec, and one for the constraint `ratel create`
/// pins for `ratel_generator`. Both silently go stale on the next bump, so
/// they are pinned down here rather than trusted.
String _constant(String source, String name) =>
    RegExp("const $name = '([^']+)';").firstMatch(source)!.group(1)!;

String _version(String pubspec) =>
    RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec)!
        .group(1)!;

void main() {
  final source = File('lib/src/cli/version.dart').readAsStringSync();

  test('the fallback version matches this package', () {
    expect(
      _constant(source, '_fallbackVersion'),
      _version(File('pubspec.yaml').readAsStringSync()),
    );
  });

  test('the scaffolded ratel_generator constraint matches that package', () {
    expect(
      _constant(source, 'generatorVersion'),
      _version(File('../ratel_generator/pubspec.yaml').readAsStringSync()),
    );
  });
}
