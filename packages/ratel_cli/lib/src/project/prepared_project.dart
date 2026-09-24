import 'dart:io';

import '../engine/generation_run.dart';
import '../engine/model/generation_mode.dart';
import '../engine/project_analyzer.dart';
import '../process/dart_sdk.dart';
import 'leftovers.dart';
import 'project_runtimes.dart';
import 'pub_get.dart';
import 'ratel_project.dart';
import 'runtime_compatibility.dart';

final class PreparedProject {
  PreparedProject._(
      this.project, this.entrypoint, this.analyzer, this.runtimes);

  final RatelProject project;
  final File? entrypoint;
  ProjectAnalyzer analyzer;
  ProjectRuntimes runtimes;
  String? incompatibility;

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
    return open(project, entrypoint);
  }

  static Future<PreparedProject?> open(
    RatelProject project,
    File? entrypoint,
  ) async {
    final analyzer = ProjectAnalyzer(root: project.root, sdkPath: DartSdk.root);
    final (:runtimes, :error) = await RuntimeCompatibility.check(analyzer);
    if (runtimes == null) {
      stderr.writeln(error);
      await analyzer.dispose();
      return null;
    }
    return PreparedProject._(project, entrypoint, analyzer, runtimes);
  }

  GenerationRun generation(GenerationMode mode) => GenerationRun(
        analyzer: analyzer,
        packageName: project.name,
        mode: mode,
        runtimes: runtimes,
        entrypoint: entrypoint?.path,
      );

  Future<String?> reopen() async {
    await analyzer.dispose();
    analyzer = ProjectAnalyzer(root: project.root, sdkPath: DartSdk.root);
    final (:runtimes, :error) = await RuntimeCompatibility.check(analyzer);
    if (runtimes != null) this.runtimes = runtimes;
    return incompatibility = error;
  }

  Future<String?> changed(Set<String> paths) async {
    if (incompatibility == null && paths.isNotEmpty) {
      await analyzer.changed(paths);
    }
    return incompatibility;
  }

  Future<void> dispose() => analyzer.dispose();
}
