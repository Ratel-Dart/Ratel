import 'package:ratel_hygiene/src/rules/file_name_rule.dart';
import 'package:test/test.dart';

import '../support/temp_package.dart';

void main() {
  late TempPackage package;

  setUp(() async => package = await TempPackage.create());
  tearDown(() => package.delete());

  test('accepts a file named after its type', () {
    final file =
        package.file('lib/src/open_api_spec.dart', 'class OpenApiSpec {}\n');
    expect(const FileNameRule().check(file), isEmpty);
  });

  test('flags a file named after something else', () {
    final file = package.file('lib/src/helpers.dart', 'class RoutePath {}\n');
    expect(
      const FileNameRule().check(file).single.message,
      contains('route_path.dart'),
    );
  });

  test('flags a private declaration', () {
    final file = package.file('lib/src/a.dart', 'class _A {}\n');
    expect(const FileNameRule().check(file), hasLength(1));
  });
}
