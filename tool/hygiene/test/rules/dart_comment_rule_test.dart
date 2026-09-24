import 'package:ratel_hygiene/src/rules/dart_comment_rule.dart';
import 'package:test/test.dart';

import '../support/temp_package.dart';

void main() {
  late TempPackage package;

  setUp(() async => package = await TempPackage.create());
  tearDown(() => package.delete());

  test('flags line, doc and block comments', () {
    final file = package.file(
      'lib/src/a.dart',
      '/// doc\nclass A {\n  // line\n  /* block */\n  int x = 1;\n}\n',
    );
    final lines = const DartCommentRule()
        .check(file)
        .map((violation) => violation.line)
        .toList();
    expect(lines, [1, 3, 4]);
  });

  test('ignores comment markers inside strings', () {
    final file = package.file(
      'lib/src/a.dart',
      "class A {\n  final url = 'https://example.com/*x*/';\n}\n",
    );
    expect(const DartCommentRule().check(file), isEmpty);
  });
}
