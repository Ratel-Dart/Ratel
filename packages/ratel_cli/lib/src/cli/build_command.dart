import 'dart:io';

import '../compile/native_compiler.dart';
import '../engine/diagnostics/diagnostic_printer.dart';
import '../engine/model/generation_mode.dart';
import '../engine/output_writer.dart';
import '../project/prepared_project.dart';

abstract final class BuildCommand {
  static Future<int> run(List<String> arguments) async {
    final prepared = await PreparedProject.prepare(
      arguments.isEmpty ? null : arguments.first,
      needsEntrypoint: true,
    );
    if (prepared == null) return 1;
    try {
      final run = prepared.generation(GenerationMode.build);
      final result = await run.run();
      if (result.diagnostics.isNotEmpty) {
        stdout.writeln(
          DiagnosticPrinter.format(result.diagnostics, prepared.project.root),
        );
      }
      if (result.hasErrors) return 1;
      OutputWriter.write(run.outputDirectory, result.files);
      stdout.writeln('Compiling...');
      return await NativeCompiler.compile(
        root: prepared.project.root,
        entry: run.entryPath,
      );
    } finally {
      await prepared.dispose();
    }
  }
}
