import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/diagnostics/diagnostic_codes.dart';
import 'package:ratel_cli/src/engine/emit/entity_manifest_emitter.dart';
import 'package:ratel_cli/src/engine/emit/manifest_emitter.dart';
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import '../support/generated_code.dart';
import '../support/scratch_entities.dart';
import '../support/scratch_project.dart';

void main() {
  Future<(ScratchProject, GenerationResult)> generate(
    Map<String, String> files, {
    required String entrypoint,
    bool framework = true,
    bool orm = true,
  }) async {
    final project = await ScratchProject.create(
      'shelf',
      files,
      packages: {if (orm) 'ratel_orm': ScratchEntities.ormStub},
      framework: framework,
    );
    addTearDown(project.dispose);
    final result = await project.generate(write: true, entrypoint: entrypoint);
    expect(result.hasErrors, isFalse, reason: '${result.diagnostics}');
    return (project, result);
  }

  List<String> files(GenerationResult result) =>
      [for (final file in result.files) file.relativePath];

  Future<void> expectClean(ScratchProject project, List<String> names) async {
    final paths = [for (final name in names) p.join(project.output, name)];
    final problems = await GeneratedCode.problems(paths);
    for (final path in paths) {
      expect(problems[path], isEmpty, reason: path);
      expect(GeneratedCode.hasComments(path), isFalse, reason: path);
      expect(GeneratedCode.declarations(path), hasLength(1), reason: path);
    }
  }

  test('an ORM-only project gets an entity manifest and an entry', () async {
    final (project, result) = await generate(
      ScratchEntities.library,
      entrypoint: 'bin/main.dart',
      framework: false,
    );
    expect(files(result), [EntityManifestEmitter.file, 'main.dart']);
    expect(
      result.diagnostics.map((diagnostic) => diagnostic.code),
      isNot(contains(DiagnosticCodes.noControllers)),
    );
    await expectClean(project, files(result));
  });

  test('an ORM-only project without entities still gets a manifest', () async {
    final (project, result) = await generate(
      ScratchEntities.empty,
      entrypoint: 'bin/main.dart',
      framework: false,
    );
    expect(result.app.entities, isEmpty);
    final manifest = result.files.first;
    expect(manifest.relativePath, EntityManifestEmitter.file);
    expect(manifest.contents, contains('    entities: [\n    ],\n'));
    await expectClean(project, files(result));
  });

  test('a framework project without ratel_orm gets no entity manifest',
      () async {
    final (project, result) = await generate(
      {
        for (final MapEntry(:key, :value) in ScratchEntities.bookshelf.entries)
          if (!key.contains('entities') && !key.startsWith('tool')) key: value,
        'lib/entities/note.dart': 'class Note {\n'
            '  Note({this.id, required this.text});\n\n'
            '  final int? id;\n'
            '  final String text;\n'
            '}\n',
        'bin/server.dart': 'void main() {}\n',
      },
      entrypoint: 'bin/server.dart',
      orm: false,
    );
    expect(files(result), [ManifestEmitter.file, 'server.dart']);
    final manifest = result.files.first.contents;
    expect(manifest, isNot(contains('ratel_orm')));
    expect(manifest, isNot(contains('isolateSetup')));
    await expectClean(project, files(result));
  });

  group('a project with both runtimes', () {
    late ScratchProject project;
    late GenerationResult result;

    setUpAll(() async {
      project = await ScratchProject.create(
        'shelf',
        ScratchEntities.bookshelf,
        packages: {'ratel_orm': ScratchEntities.ormStub},
      );
      result =
          await project.generate(write: true, entrypoint: 'bin/server.dart');
      expect(result.hasErrors, isFalse, reason: '${result.diagnostics}');
    });

    tearDownAll(() => project.dispose());

    test('gets both manifests and an entry that installs both', () async {
      expect(files(result), [
        ManifestEmitter.file,
        EntityManifestEmitter.file,
        'server.dart',
      ]);
      await expectClean(project, files(result));
    });

    test('installs the entities in every isolate through isolateSetup', () {
      final manifest = result.files.first.contents;
      expect(
        manifest,
        contains("import 'package:ratel_orm/runtime.dart' as o;"),
      );
      expect(manifest, contains("import 'ratel_entity_manifest.dart';"));
      expect(manifest, contains('    isolateSetup: [_installEntities],\n'));
      expect(
        manifest,
        contains('  static void _installEntities() =>\n'
            '      o.RatelOrmRuntime.install(RatelEntityManifest.manifest);\n'),
      );
    });

    test('the isolate setup installs the entity manifest', () async {
      final probe = await project.run('tool/probe.dart');
      expect(probe.exitCode, 0, reason: '${probe.stdout}${probe.stderr}');
      expect('${probe.stdout}'.trim(), 'true true');
    });

    test('the entry installs the entities before running the app', () async {
      final entry = await Process.run(
        DartSdk.dart,
        [
          '--packages=${project.packageConfig}',
          p.join(project.output, 'server.dart'),
        ],
        workingDirectory: project.root,
      );
      expect(entry.exitCode, 0, reason: '${entry.stdout}${entry.stderr}');
      expect('${entry.stdout}'.trim(), 'entities 1');
    });
  });
}
