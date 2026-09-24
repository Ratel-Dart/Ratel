import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/emit/suite_wrapper_emitter.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ratel_wrapper');
  });

  tearDown(() => root.delete(recursive: true));

  String wrap(String source) {
    final suite = File(p.join(root.path, 'test', 'http', 'hello_test.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
    final output = p.join(root.path, '.dart_tool', 'ratel', 'test');
    return SuiteWrapperEmitter.emit(
      suite: suite.path,
      wrapperDirectory: p.join(output, 'suites', 'test', 'http'),
      manifestDirectory: output,
    );
  }

  test('installs the manifest and runs the original suite', () {
    final wrapper = wrap("import 'package:test/test.dart';\n\n"
        "void main() {\n  test('x', () {});\n}\n");
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
}
