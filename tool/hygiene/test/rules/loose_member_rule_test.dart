import 'package:ratel_hygiene/src/rules/loose_member_rule.dart';
import 'package:test/test.dart';

import '../support/temp_package.dart';

void main() {
  late TempPackage package;

  setUp(() async => package = await TempPackage.create());
  tearDown(() => package.delete());

  test('flags top-level functions and variables', () {
    final file = package.file(
      'lib/src/a.dart',
      'final x = 1;\n\nint helper() => 2;\n',
    );
    expect(const LooseMemberRule().check(file), hasLength(2));
  });

  test('accepts main outside lib', () {
    final file = package.file('bin/tool.dart', 'void main() {}\n');
    expect(const LooseMemberRule().check(file), isEmpty);
  });

  test('flags main inside the lib of a library package', () {
    final file = package.file('lib/src/run.dart', 'void main() {}\n');
    expect(const LooseMemberRule().check(file), hasLength(1));
  });
}
