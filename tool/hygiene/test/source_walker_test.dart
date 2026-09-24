import 'package:path/path.dart' as p;
import 'package:ratel_hygiene/src/source_walker.dart';
import 'package:test/test.dart';

import 'support/temp_package.dart';

void main() {
  late TempPackage package;

  setUp(() async {
    package = await TempPackage.create();
    package
      ..write('lib/src/a.dart', 'class A {}\n')
      ..write('lib/src/build/b.dart', 'class B {}\n')
      ..write('build/main.dart', 'void main() {}\n')
      ..write('.dart_tool/ratel/build/manifest.dart', 'class M {}\n')
      ..write('.dart_tool/package_config.json', '{}\n');
  });

  tearDown(() => package.delete());

  List<String> relative(List<String> files) => [
        for (final file in files)
          p.posix.joinAll(p.split(p.relative(file, from: package.root))),
      ];

  test('skips tool folders and the build output of a package', () {
    expect(
      relative(SourceWalker.files([package.root])),
      [
        'lib/sample.dart',
        'lib/src/a.dart',
        'lib/src/build/b.dart',
        'pubspec.yaml'
      ],
    );
  });

  test('walks generated code when it is the root it is given', () {
    final generated = p.join(package.root, '.dart_tool', 'ratel');
    expect(
      relative(SourceWalker.files([generated])),
      ['.dart_tool/ratel/build/manifest.dart'],
    );
  });
}
