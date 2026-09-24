import 'dart:io';

import 'package:path/path.dart' as p;

import '../engine/diagnostics/diagnostic_printer.dart';
import '../engine/emit/suite_wrapper_emitter.dart';
import '../engine/generated_file.dart';
import '../engine/model/generation_mode.dart';
import '../engine/output_writer.dart';
import '../process/dart_process.dart';
import '../project/prepared_project.dart';
import '../project/test_suites.dart';

abstract final class TestCommand {
  static const _suitesFolder = 'suites';

  static Future<int> run(List<String> arguments) async {
    final separator = arguments.indexOf('--');
    final paths = separator < 0 ? arguments : arguments.sublist(0, separator);
    final forwarded =
        separator < 0 ? const <String>[] : arguments.sublist(separator + 1);

    final prepared =
        await PreparedProject.prepare(null, needsEntrypoint: false);
    if (prepared == null) return 1;
    try {
      final root = prepared.project.root;
      final run = prepared.generation(GenerationMode.test);
      final result = await run.run();
      if (result.diagnostics.isNotEmpty) {
        stdout.writeln(DiagnosticPrinter.format(result.diagnostics, root));
      }
      if (result.hasErrors) return 1;

      final suites = TestSuites.find(root, paths);
      if (suites.isEmpty) {
        stderr.writeln('No *_test.dart files found.');
        return 1;
      }
      final wrappers = <String>[];
      final files = [...result.files];
      for (final suite in suites) {
        final relative = p.relative(suite, from: root);
        final wrapper = p.join(run.outputDirectory, _suitesFolder, relative);
        wrappers.add(wrapper);
        files.add(GeneratedFile(
          p.join(_suitesFolder, relative),
          SuiteWrapperEmitter.emit(
            suite: suite,
            wrapperDirectory: p.dirname(wrapper),
            manifestDirectory: run.outputDirectory,
            runtimes: prepared.runtimes,
          ),
        ));
      }
      OutputWriter.write(run.outputDirectory, files);
      return await DartProcess.run(
        [
          'test',
          ...forwarded,
          for (final wrapper in wrappers) p.relative(wrapper, from: root),
        ],
        workingDirectory: root,
      );
    } finally {
      await prepared.dispose();
    }
  }
}
