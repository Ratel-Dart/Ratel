import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';

abstract final class RuntimeContractReader {
  static const runtimeLibrary = 'package:ratel/runtime.dart';

  static Future<int?> read(AnalysisSession session) async {
    final result = await session.getLibraryByUri(runtimeLibrary);
    if (result is! LibraryElementResult) return null;
    final runtime = result.element.exportNamespace.get2('RatelRuntime');
    if (runtime is! ClassElement) return null;
    return runtime.getField('contract')?.computeConstantValue()?.toIntValue();
  }
}
