import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:ratel_cli/src/engine/generation_run.dart';
import 'package:ratel_cli/src/engine/model/generation_mode.dart';
import 'package:ratel_cli/src/engine/output_writer.dart';
import 'package:ratel_cli/src/engine/project_analyzer.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';

abstract final class EngineHarness {
  static String fixture(String name) =>
      p.normalize(p.absolute(p.join('test', 'fixtures', name)));

  static Future<GenerationResult> generate(
    String name, {
    required String packageName,
    GenerationMode mode = GenerationMode.build,
    bool write = false,
  }) async {
    final root = fixture(name);
    final analyzer = ProjectAnalyzer(root: root, sdkPath: DartSdk.root);
    try {
      final run = GenerationRun(
        analyzer: analyzer,
        packageName: packageName,
        mode: mode,
        entrypoint: p.join(root, 'bin', 'server.dart'),
      );
      final result = await run.run();
      if (write && !result.hasErrors) {
        OutputWriter.write(run.outputDirectory, result.files);
      }
      return result;
    } finally {
      await analyzer.dispose();
    }
  }

  static String output(String name, GenerationMode mode) =>
      p.join(fixture(name), '.dart_tool', 'ratel', mode.name);
}
