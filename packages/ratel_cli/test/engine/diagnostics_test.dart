import 'package:ratel_cli/src/engine/diagnostics/diagnostic_codes.dart';
import 'package:test/test.dart';

import '../support/engine_harness.dart';

void main() {
  test('reports misplaced annotations and writes nothing', () async {
    final result = await EngineHarness.generate(
      'broken_app',
      packageName: 'broken_app',
    );
    expect(result.hasErrors, isTrue);
    expect(result.files, isEmpty);
    final codes = {
      for (final diagnostic in result.diagnostics) diagnostic.code
    };
    expect(
      codes,
      containsAll([
        DiagnosticCodes.missingController,
        DiagnosticCodes.bodyNotJson,
      ]),
    );
    final orphan = result.diagnostics.singleWhere(
      (diagnostic) => diagnostic.code == DiagnosticCodes.missingController,
    );
    expect(orphan.path, endsWith('orphan.dart'));
    expect(orphan.line, 5);
  });
}
