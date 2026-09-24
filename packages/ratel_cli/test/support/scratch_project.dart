import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:ratel_cli/src/engine/generation_run.dart';
import 'package:ratel_cli/src/engine/model/generation_mode.dart';
import 'package:ratel_cli/src/engine/output_writer.dart';
import 'package:ratel_cli/src/engine/project_analyzer.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:ratel_cli/src/project/runtime_compatibility.dart';

final class ScratchProject {
  ScratchProject._(this.root, this.name)
      : _analyzer = ProjectAnalyzer(root: root, sdkPath: DartSdk.root);

  final String root;
  final String name;
  final ProjectAnalyzer _analyzer;

  String get packageConfig => p.join(root, '.dart_tool', 'package_config.json');

  String get output => p.join(root, '.dart_tool', 'ratel', 'build');

  ProjectAnalyzer get analyzer => _analyzer;

  static Future<ScratchProject> create(
    String name,
    Map<String, String> files, {
    Map<String, Map<String, String>> packages = const {},
    Map<String, String> external = const {},
    bool framework = true,
  }) async {
    final temp = await Directory.systemTemp.createTemp('ratel_$name');
    final root = p.normalize(temp.resolveSymbolicLinksSync());
    final roots = {
      name: root,
      for (final package in packages.keys)
        package: p.join(root, 'packages', package),
    };
    _write(
      p.join(root, 'pubspec.yaml'),
      'name: $name\npublish_to: none\n\nenvironment:\n  sdk: ^3.13.0\n',
    );
    final sources = {name: files, ...packages};
    for (final MapEntry(key: package, value: directory) in roots.entries) {
      for (final MapEntry(:key, :value) in sources[package]!.entries) {
        _write(p.join(directory, key), value);
      }
    }
    final workspace = await findPackageConfig(Directory.current);
    if (workspace == null) {
      throw StateError('Run the tests from inside the Ratel workspace.');
    }
    final hidden = {
      ...roots.keys,
      ...external.keys,
      if (!framework) 'ratel',
    };
    final config = PackageConfig([
      for (final package in workspace.packages)
        if (!hidden.contains(package.name)) package,
      for (final MapEntry(key: package, value: directory) in roots.entries)
        Package(
          package,
          Uri.directory(directory),
          packageUriRoot: Uri.directory(p.join(directory, 'lib')),
          languageVersion: LanguageVersion(3, 13),
        ),
      for (final MapEntry(key: package, value: directory) in external.entries)
        Package(
          package,
          Uri.directory(directory),
          packageUriRoot: Uri.directory(p.join(directory, 'lib')),
          languageVersion: LanguageVersion(3, 6),
        ),
    ]);
    final buffer = StringBuffer();
    PackageConfig.writeString(config, buffer);
    _write(p.join(root, '.dart_tool', 'package_config.json'), '$buffer');
    return ScratchProject._(root, name);
  }

  Future<GenerationResult> generate({
    bool write = false,
    String? entrypoint,
  }) async {
    final (:runtimes, :error) = await RuntimeCompatibility.check(_analyzer);
    if (runtimes == null) throw StateError('$error');
    final run = GenerationRun(
      analyzer: _analyzer,
      packageName: name,
      mode: GenerationMode.build,
      runtimes: runtimes,
      entrypoint: entrypoint == null ? null : p.join(root, entrypoint),
    );
    final result = await run.run();
    if (write && !result.hasErrors) {
      OutputWriter.write(run.outputDirectory, result.files);
    }
    return result;
  }

  Future<LibraryElement> library(String relative) async {
    final result = await _analyzer.session
        .getResolvedLibrary(p.normalize(p.join(root, relative)));
    return (result as ResolvedLibraryResult).element;
  }

  Future<ProcessResult> run(String relative) => Process.run(
        DartSdk.dart,
        ['--packages=$packageConfig', p.join(root, relative)],
        workingDirectory: root,
      );

  Future<void> dispose() async {
    await _analyzer.dispose();
    await Directory(root).delete(recursive: true);
  }

  static void _write(String path, String contents) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(contents);
  }
}
