import 'package:analyzer/dart/analysis/results.dart';

import '../cli/ratel_cli_version.dart';
import '../engine/analysis/runtime_contract_reader.dart';
import '../engine/project_analyzer.dart';

abstract final class RuntimeCompatibility {
  static Future<String?> check(ProjectAnalyzer analyzer) async {
    final contract = await RuntimeContractReader.read(analyzer.session);
    if (contract == RatelCliVersion.contract) return null;
    if (contract != null) {
      return 'ratel_cli ${RatelCliVersion.current} generates code for runtime '
          'contract ${RatelCliVersion.contract}, but this app resolves a ratel '
          'with contract $contract. Install the matching CLI: '
          'dart pub global activate ratel_cli <the ratel version in '
          'pubspec.lock>';
    }
    final ratel =
        await analyzer.session.getLibraryByUri('package:ratel/ratel.dart');
    if (ratel is LibraryElementResult) {
      return 'This app resolves a ratel that predates generation by the CLI '
          '(it has no package:ratel/runtime.dart). Run: dart pub upgrade ratel';
    }
    return 'This project does not depend on ratel. Run: dart pub add ratel';
  }
}
