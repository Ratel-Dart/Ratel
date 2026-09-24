import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:path/path.dart' as p;

final class ProjectAnalyzer {
  ProjectAnalyzer({required String root, required String sdkPath})
      : root = p.normalize(p.absolute(root)),
        _collection = AnalysisContextCollection(
          includedPaths: [p.normalize(p.absolute(root))],
          sdkPath: sdkPath,
        );

  final String root;
  final AnalysisContextCollection _collection;

  AnalysisContext get context => _collection.contextFor(root);

  AnalysisSession get session => context.currentSession;

  Future<void> changed(Iterable<String> paths) async {
    for (final path in paths) {
      context.changeFile(p.normalize(p.absolute(path)));
    }
    await context.applyPendingFileChanges();
  }

  Future<void> dispose() => _collection.dispose();
}
