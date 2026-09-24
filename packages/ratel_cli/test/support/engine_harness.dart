import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:ratel_cli/src/engine/generation_run.dart';
import 'package:ratel_cli/src/engine/model/generation_mode.dart';
import 'package:ratel_cli/src/engine/output_writer.dart';
import 'package:ratel_cli/src/engine/project_analyzer.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:ratel_cli/src/project/runtime_compatibility.dart';

abstract final class EngineHarness {
  static String fixture(String name) =>
      p.normalize(p.absolute(p.join('test', 'fixtures', name)));

  static Future<GenerationResult> generate(
    String name, {
    required String packageName,
    GenerationMode mode = GenerationMode.build,
    bool write = false,
  }) =>
      generateAt(
        fixture(name),
        packageName: packageName,
        mode: mode,
        write: write,
      );

  static Future<GenerationResult> generateAt(
    String root, {
    required String packageName,
    String entrypoint = 'bin/server.dart',
    GenerationMode mode = GenerationMode.build,
    bool write = false,
  }) async {
    final analyzer = ProjectAnalyzer(root: root, sdkPath: DartSdk.root);
    try {
      final (:runtimes, :error) = await RuntimeCompatibility.check(analyzer);
      if (runtimes == null) throw StateError('$error');
      final run = GenerationRun(
        analyzer: analyzer,
        packageName: packageName,
        mode: mode,
        runtimes: runtimes,
        entrypoint: p.join(root, entrypoint),
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
      outputAt(fixture(name), mode);

  static String outputAt(String root, GenerationMode mode) =>
      p.join(root, '.dart_tool', 'ratel', mode.name);
}
