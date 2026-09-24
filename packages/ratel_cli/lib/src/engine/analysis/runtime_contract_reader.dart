import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';

abstract final class RuntimeContractReader {
  static const ratelLibrary = 'package:ratel/runtime.dart';
  static const ratelRuntime = 'RatelRuntime';
  static const ormLibrary = 'package:ratel_orm/runtime.dart';
  static const ormRuntime = 'RatelOrmRuntime';

  static Future<int?> read(
    AnalysisSession session, {
    required String library,
    required String runtime,
  }) async {
    final result = await session.getLibraryByUri(library);
    if (result is! LibraryElementResult) return null;
    final element = result.element.exportNamespace.get2(runtime);
    if (element is! ClassElement) return null;
    return element.getField('contract')?.computeConstantValue()?.toIntValue();
  }

  static Future<bool> resolves(AnalysisSession session, String library) async {
    final path = session.uriConverter.uriToPath(Uri.parse(library));
    if (path == null || !session.resourceProvider.getFile(path).exists) {
      return false;
    }
    return await session.getLibraryByUri(library) is LibraryElementResult;
  }
}
