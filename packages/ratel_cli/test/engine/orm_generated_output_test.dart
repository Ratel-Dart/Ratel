@Tags(['orm'])
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/emit/dev_watchdog_emitter.dart';
import 'package:ratel_cli/src/engine/emit/entity_manifest_emitter.dart';
import 'package:ratel_cli/src/engine/emit/manifest_emitter.dart';
import 'package:ratel_cli/src/engine/model/generation_mode.dart';
import 'package:test/test.dart';

import '../support/engine_harness.dart';
import '../support/generated_code.dart';
import '../support/orm_fixture.dart';

void main() {
  late Directory workspace;
  late Directory ormApp;
  late Directory ormOnly;

  String appOutput(String file) =>
      p.join(EngineHarness.outputAt(ormApp.path, GenerationMode.build), file);

  String scriptOutput(String file) =>
      p.join(EngineHarness.outputAt(ormOnly.path, GenerationMode.dev), file);

  List<String> generated() => [
        appOutput(ManifestEmitter.file),
        appOutput(EntityManifestEmitter.file),
        appOutput('server.dart'),
        scriptOutput(EntityManifestEmitter.file),
        scriptOutput(DevWatchdogEmitter.file),
        scriptOutput('main.dart'),
      ];

  setUpAll(() async {
    workspace = await Directory.systemTemp.createTemp('ratel_orm_output');
    ormApp = await OrmFixture.copy('orm_app', workspace);
    ormOnly = await OrmFixture.copy('orm_only', workspace);
    final app = await EngineHarness.generateAt(
      ormApp.path,
      packageName: 'orm_app',
      write: true,
    );
    expect(app.hasErrors, isFalse, reason: '${app.diagnostics}');
    expect(app.diagnostics, isEmpty);
    final script = await EngineHarness.generateAt(
      ormOnly.path,
      packageName: 'orm_only',
      entrypoint: 'bin/main.dart',
      mode: GenerationMode.dev,
      write: true,
    );
    expect(script.hasErrors, isFalse, reason: '${script.diagnostics}');
    expect(script.diagnostics, isEmpty);
  });

  tearDownAll(() => workspace.delete(recursive: true));

  test('writes an entity manifest next to each entry', () {
    for (final path in generated()) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(File(scriptOutput(ManifestEmitter.file)).existsSync(), isFalse);
  });

  test('maps the entities of both fixtures', () {
    final app = File(appOutput(EntityManifestEmitter.file)).readAsStringSync();
    expect(app, contains("o.EntityDefinition<i1.User>(\n"));
    expect(app, contains("table: 'users',"));
    expect(
        app, contains("o.ColumnDefinition(field: 'email', name: 'e_mail'),"));
    expect(app, contains("row.enumeration('role', i2.UserRole.values)"));
    final script =
        File(scriptOutput(EntityManifestEmitter.file)).readAsStringSync();
    expect(script, contains("..archived = row.boolean('archived')"));
    expect(script, contains("'status': entity.status.name,"));
    expect(script, isNot(contains('selected')));
  });

  test('installs the entities in every isolate of a framework app', () {
    final manifest = File(appOutput(ManifestEmitter.file)).readAsStringSync();
    expect(manifest, contains('isolateSetup: [_installEntities],'));
    expect(
      manifest,
      contains('o.RatelOrmRuntime.install(RatelEntityManifest.manifest);'),
    );
    final entry = File(appOutput('server.dart')).readAsStringSync();
    expect(
      entry.indexOf('o.RatelOrmRuntime.install('),
      lessThan(entry.indexOf('r.RatelRuntime.install(')),
    );
  });

  test('leaves ratel out of an ORM-only entry', () {
    final entry = File(scriptOutput('main.dart')).readAsStringSync();
    expect(entry, isNot(contains('package:ratel/')));
    expect(entry, contains('await RatelDevWatchdog.attach();'));
    expect(
      entry,
      contains('o.RatelOrmRuntime.install(RatelEntityManifest.manifest);'),
    );
  });

  test('the generated code and the fixtures analyze cleanly', () async {
    final sources = [
      for (final app in [ormApp, ormOnly])
        for (final folder in ['bin', 'lib', 'test'])
          if (Directory(p.join(app.path, folder)).existsSync())
            for (final entity in Directory(p.join(app.path, folder))
                .listSync(recursive: true))
              if (entity is File && entity.path.endsWith('.dart')) entity.path,
    ];
    final problems = await GeneratedCode.problems([...generated(), ...sources]);
    for (final MapEntry(key: path, value: found) in problems.entries) {
      expect(found, isEmpty, reason: path);
    }
  });

  test('the generated code carries no comments', () {
    for (final path in generated()) {
      expect(GeneratedCode.hasComments(path), isFalse, reason: path);
    }
  });

  test('each generated file holds one declaration', () {
    for (final path in generated()) {
      final declarations = GeneratedCode.declarations(path);
      expect(declarations, hasLength(1), reason: path);
      final declaration = declarations.single;
      if (p.basename(path) case 'server.dart' || 'main.dart') {
        expect(
          (declaration as FunctionDeclaration).name.lexeme,
          'main',
          reason: path,
        );
      } else {
        expect(declaration, isA<ClassDeclaration>(), reason: path);
      }
    }
  });
}
