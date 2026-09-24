import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/emit/suite_wrapper_emitter.dart';
import 'package:ratel_cli/src/project/project_runtimes.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ratel_wrapper');
  });

  tearDown(() => root.delete(recursive: true));

  String wrap(
    String source, {
    ProjectRuntimes runtimes =
        const ProjectRuntimes(framework: true, orm: false),
  }) {
    final suite = File(p.join(root.path, 'test', 'http', 'hello_test.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
    final output = p.join(root.path, '.dart_tool', 'ratel', 'test');
    return SuiteWrapperEmitter.emit(
      suite: suite.path,
      wrapperDirectory: p.join(output, 'suites', 'test', 'http'),
      manifestDirectory: output,
      runtimes: runtimes,
    );
  }

  const plainSuite = "import 'package:test/test.dart';\n\n"
      "void main() {\n  test('x', () {});\n}\n";

  test('installs the manifest and runs the original suite', () {
    final wrapper = wrap(plainSuite);
    expect(
      wrapper,
      contains(
          "import '../../../../../../test/http/hello_test.dart' as suite;"),
    );
    expect(wrapper, contains("import '../../../ratel_app_manifest.dart';"));
    expect(wrapper,
        contains('r.RatelRuntime.install(RatelAppManifest.manifest);'));
    expect(wrapper, contains('  suite.main();'));
    expect(wrapper, isNot(contains('library;')));
    expect(wrapper, isNot(contains('ratel_orm')));
  });

  test('carries the suite annotations and awaits an async main', () {
    final wrapper = wrap("@Tags(['http'])\n@t.Timeout(Duration(seconds: 5))\n"
        "library;\n\n"
        "import 'package:test/test.dart';\n"
        "import 'package:test/test.dart' as t;\n\n"
        "Future<void> main() async {}\n");
    expect(
        wrapper,
        startsWith(
            "@Tags(['http'])\n@t.Timeout(Duration(seconds: 5))\nlibrary;"));
    expect(wrapper, contains("import 'package:test/test.dart';"));
    expect(wrapper, contains("import 'package:test/test.dart' as t;"));
    expect(wrapper, contains('  await suite.main();'));
  });

  test('installs only the entity manifest in an ORM-only project', () {
    final wrapper = wrap(
      plainSuite,
      runtimes: const ProjectRuntimes(framework: false, orm: true),
    );
    expect(
      wrapper,
      startsWith("import 'package:ratel_orm/runtime.dart' as o;\n"),
    );
    expect(wrapper, contains("import '../../../ratel_entity_manifest.dart';"));
    expect(
      wrapper,
      contains('  o.RatelOrmRuntime.install(RatelEntityManifest.manifest);\n'
          '  suite.main();\n'),
    );
    expect(wrapper, isNot(contains('package:ratel/')));
    expect(wrapper, isNot(contains('RatelAppManifest')));
  });

  test('installs the entities before the app when both are present', () {
    final wrapper = wrap(
      plainSuite,
      runtimes: const ProjectRuntimes(framework: true, orm: true),
    );
    expect(
      wrapper,
      startsWith("import 'package:ratel/runtime.dart' as r;\n"
          "import 'package:ratel_orm/runtime.dart' as o;\n"),
    );
    expect(
      wrapper,
      contains("import '../../../ratel_app_manifest.dart';\n"
          "import '../../../ratel_entity_manifest.dart';\n"),
    );
    expect(
      wrapper,
      contains('  o.RatelOrmRuntime.install(RatelEntityManifest.manifest);\n'
          '  r.RatelRuntime.install(RatelAppManifest.manifest);\n'),
    );
  });
}
