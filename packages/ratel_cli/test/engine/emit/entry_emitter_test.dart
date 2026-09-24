import 'package:ratel_cli/src/engine/emit/entry_emitter.dart';
import 'package:ratel_cli/src/engine/model/entry_signature.dart';
import 'package:ratel_cli/src/project/project_runtimes.dart';
import 'package:test/test.dart';

void main() {
  const framework = ProjectRuntimes(framework: true, orm: false);
  const orm = ProjectRuntimes(framework: false, orm: true);
  const both = ProjectRuntimes(framework: true, orm: true);
  const signature = EntrySignature(takesArguments: true, returnsFuture: true);

  String emit(ProjectRuntimes runtimes, {bool watchdog = false}) =>
      EntryEmitter.emit(
        entrypointImport: 'package:app/main.dart',
        signature: signature,
        runtimes: runtimes,
        watchdog: watchdog,
      );

  test('installs only the app manifest for a framework project', () {
    expect(
      emit(framework),
      "import 'package:ratel/runtime.dart' as r;\n"
      '\n'
      "import 'package:app/main.dart' as entrypoint;\n"
      "import 'ratel_app_manifest.dart';\n"
      '\n'
      'Future<void> main(List<String> args) async {\n'
      '  r.RatelRuntime.install(RatelAppManifest.manifest);\n'
      '  await entrypoint.main(args);\n'
      '}\n',
    );
  });

  test('installs only the entity manifest for an ORM-only project', () {
    expect(
      emit(orm),
      "import 'package:ratel_orm/runtime.dart' as o;\n"
      '\n'
      "import 'package:app/main.dart' as entrypoint;\n"
      "import 'ratel_entity_manifest.dart';\n"
      '\n'
      'Future<void> main(List<String> args) async {\n'
      '  o.RatelOrmRuntime.install(RatelEntityManifest.manifest);\n'
      '  await entrypoint.main(args);\n'
      '}\n',
    );
  });

  test('installs the entities before the app when both are present', () {
    expect(
      emit(both, watchdog: true),
      "import 'package:ratel/runtime.dart' as r;\n"
      "import 'package:ratel_orm/runtime.dart' as o;\n"
      '\n'
      "import 'package:app/main.dart' as entrypoint;\n"
      "import 'ratel_app_manifest.dart';\n"
      "import 'ratel_dev_watchdog.dart';\n"
      "import 'ratel_entity_manifest.dart';\n"
      '\n'
      'Future<void> main(List<String> args) async {\n'
      '  await RatelDevWatchdog.attach();\n'
      '  o.RatelOrmRuntime.install(RatelEntityManifest.manifest);\n'
      '  r.RatelRuntime.install(RatelAppManifest.manifest);\n'
      '  await entrypoint.main(args);\n'
      '}\n',
    );
  });

  test('keeps the watchdog and a synchronous main without arguments', () {
    final entry = EntryEmitter.emit(
      entrypointImport: '../../../bin/main.dart',
      signature: const EntrySignature(
        takesArguments: false,
        returnsFuture: false,
      ),
      runtimes: orm,
      watchdog: true,
    );
    expect(entry, contains("import 'ratel_dev_watchdog.dart';\n"));
    expect(entry, contains('  await RatelDevWatchdog.attach();\n'));
    expect(entry, contains('  entrypoint.main();\n'));
    expect(entry, isNot(contains('package:ratel/')));
  });
}
