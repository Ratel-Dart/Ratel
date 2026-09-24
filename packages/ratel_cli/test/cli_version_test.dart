import 'dart:io';

import 'package:ratel_cli/src/cli/ratel_cli_version.dart';
import 'package:ratel_cli/src/engine/analysis/runtime_contract_reader.dart';
import 'package:ratel_cli/src/engine/project_analyzer.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';

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

  test('the CLI generates for the contract the runtime declares', () async {
    final analyzer = ProjectAnalyzer(
      root: EngineHarness.fixture('kitchen_sink'),
      sdkPath: DartSdk.root,
    );
    addTearDown(analyzer.dispose);
    expect(
      await RuntimeContractReader.read(analyzer.session),
      RatelCliVersion.contract,
    );
  });
}
