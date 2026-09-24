import 'diagnostics/ratel_diagnostic.dart';
import 'generated_file.dart';
import 'model/scanned_app.dart';

final class GenerationResult {
  const GenerationResult({
    required this.app,
    required this.files,
    required this.diagnostics,
  });

  final ScannedApp app;
  final List<GeneratedFile> files;
  final List<RatelDiagnostic> diagnostics;

  bool get hasErrors => diagnostics.any((diagnostic) => diagnostic.isError);
}
