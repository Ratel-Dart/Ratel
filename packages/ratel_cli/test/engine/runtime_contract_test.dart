import 'package:ratel_cli/src/engine/analysis/runtime_contract_reader.dart';
import 'package:ratel_cli/src/engine/project_analyzer.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import '../support/engine_harness.dart';

void main() {
  test('reads the runtime contract the app resolves', () async {
    final analyzer = ProjectAnalyzer(
      root: EngineHarness.fixture('kitchen_sink'),
      sdkPath: DartSdk.root,
    );
    addTearDown(analyzer.dispose);
    expect(await RuntimeContractReader.read(analyzer.session), 1);
  });
}
