import 'dart:io';

import '../engine/generation_run.dart';
import '../engine/model/generation_mode.dart';
import '../engine/project_analyzer.dart';
import '../process/dart_sdk.dart';
import 'leftovers.dart';
import 'pub_get.dart';
import 'ratel_project.dart';
import 'runtime_compatibility.dart';

final class PreparedProject {
  PreparedProject._(this.project, this.entrypoint, this.analyzer);

  final RatelProject project;
  final File? entrypoint;
  ProjectAnalyzer analyzer;

  static Future<PreparedProject?> prepare(
    String? entrypointArgument, {
    required bool needsEntrypoint,
  }) async {
    final project = RatelProject.locate(Directory.current);
    if (project == null) {
      stderr.writeln('No pubspec.yaml found. Run this inside a Ratel app.');
      return null;
    }
    final entrypoint = project.resolveEntrypoint(entrypointArgument);
    if (needsEntrypoint && entrypoint == null) {
      stderr.writeln(RatelProject.entrypointHelp);
      return null;
    }
    if (await PubGet.ensure(project) != 0) return null;
    Leftovers.report(project);
    final analyzer = ProjectAnalyzer(root: project.root, sdkPath: DartSdk.root);
    final incompatibility = await RuntimeCompatibility.check(analyzer);
    if (incompatibility != null) {
      stderr.writeln(incompatibility);
      await analyzer.dispose();
      return null;
    }
    return PreparedProject._(project, entrypoint, analyzer);
  }

  GenerationRun generation(GenerationMode mode) => GenerationRun(
        analyzer: analyzer,
        packageName: project.name,
        mode: mode,
        entrypoint: entrypoint?.path,
      );

  Future<void> reopen() async {
    await analyzer.dispose();
    analyzer = ProjectAnalyzer(root: project.root, sdkPath: DartSdk.root);
  }

  Future<void> dispose() => analyzer.dispose();
}
