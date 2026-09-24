import 'package:ratel_hygiene/src/rules/config_comment_rule.dart';
import 'package:test/test.dart';

import '../support/temp_package.dart';

void main() {
  late TempPackage package;

  setUp(() async => package = await TempPackage.create());
  tearDown(() => package.delete());

  test('flags full-line and trailing comments', () {
    final file = package.file(
      'analysis_options.yaml',
      '# heading\ninclude: x.yaml  # trailing\nlinter: {}\n',
    );
    expect(
      const ConfigCommentRule().check(file).map((violation) => violation.line),
      [1, 2],
    );
  });

  test('ignores a hash inside quotes or a URL', () {
    final file = package.file(
      'pubspec.yaml',
      "name: sample\nhomepage: https://x.dev/#top\nkey: 'a # b'\n",
    );
    expect(const ConfigCommentRule().check(file), isEmpty);
  });
}
