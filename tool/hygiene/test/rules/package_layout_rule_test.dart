import 'package:ratel_hygiene/src/rules/package_layout_rule.dart';
import 'package:test/test.dart';

import '../support/temp_package.dart';

void main() {
  test('holds a library package to the lib/src layout', () async {
    final package = await TempPackage.create();
    addTearDown(package.delete);
    const rule = PackageLayoutRule();
    expect(
      rule.check(package.file('lib/sample.dart', "export 'src/a.dart';\n")),
      isEmpty,
    );
    expect(
      rule.check(package.file('lib/extra.dart', 'class Extra {}\n')),
      hasLength(1),
    );
    expect(
      rule.check(package.file('lib/core/a.dart', 'class A {}\n')),
      hasLength(1),
    );
    expect(
      rule.check(package.file('lib/src/all.dart', "export 'a.dart';\n")),
      hasLength(1),
    );
    expect(
      rule.check(package.file('lib/src/a.dart', 'class A {}\n')),
      isEmpty,
    );
  });

  test('leaves an application free to organize lib', () async {
    final app = await TempPackage.create(library: false);
    addTearDown(app.delete);
    expect(
      const PackageLayoutRule()
          .check(app.file('lib/controllers/a.dart', 'class A {}\n')),
      isEmpty,
    );
  });
}
