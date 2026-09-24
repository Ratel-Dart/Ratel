import 'package:ratel_cli/src/engine/emit/dart_literal.dart';
import 'package:test/test.dart';

void main() {
  test('quotes a plain string', () {
    expect(DartLiteral.string('items'), "'items'");
  });

  test('escapes backslashes, quotes, dollars and line breaks', () {
    expect(
      DartLiteral.string('a\\b \'c\' \$d\ne\rf'),
      r"'a\\b \'c\' \$d\ne\rf'",
    );
  });

  test('escapes a trailing backslash so the literal stays closed', () {
    expect(DartLiteral.string(r'C:\'), r"'C:\\'");
  });

  test('writes a list of strings', () {
    expect(DartLiteral.strings(['a', r'b\']), r"['a', 'b\\']");
  });
}
