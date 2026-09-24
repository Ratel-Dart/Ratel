import 'package:ratel_hygiene/src/rules/single_declaration_rule.dart';
import 'package:test/test.dart';

import '../support/temp_package.dart';

void main() {
  late TempPackage package;

  setUp(() async => package = await TempPackage.create());
  tearDown(() => package.delete());

  test('flags every declaration after the first', () {
    final file = package.file(
      'lib/src/a.dart',
      'class A {}\n\nclass B {}\n\nenum C { x }\n',
    );
    expect(const SingleDeclarationRule().check(file), hasLength(2));
  });

  test('accepts an export-only barrel', () {
    final file = package.file('lib/sample.dart', "export 'src/a.dart';\n");
    expect(const SingleDeclarationRule().check(file), isEmpty);
  });

  test('flags a file with imports and nothing else', () {
    final file = package.file('lib/src/a.dart', "import 'dart:io';\n");
    expect(const SingleDeclarationRule().check(file), hasLength(1));
  });
}
