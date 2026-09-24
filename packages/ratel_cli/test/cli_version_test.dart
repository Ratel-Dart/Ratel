import 'dart:io';

import 'package:ratel_cli/src/cli/version.dart';
import 'package:test/test.dart';

void main() {
  String versionOf(String pubspecPath) =>
      RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(File(pubspecPath).readAsStringSync())!
          .group(1)!;

  test('the CLI reports its own package version', () {
    expect(RatelCliVersion.current, versionOf('pubspec.yaml'));
  });

  test('the CLI and the runtime are released in lockstep', () {
    expect(RatelCliVersion.current, versionOf('../ratel/pubspec.yaml'));
  });

  test('the scaffolded ratel_generator constraint matches that package', () {
    expect(
      RatelCliVersion.generator,
      versionOf('../ratel_generator/pubspec.yaml'),
    );
  });
}
