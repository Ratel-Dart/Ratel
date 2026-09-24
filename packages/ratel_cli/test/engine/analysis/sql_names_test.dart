import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/analysis/sql_names.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import '../../support/orm_fixture.dart';

void main() {
  const samples = {
    'UserAccount': 'user_account',
    'createdAt': 'created_at',
    'Gadget': 'gadget',
    'id': 'id',
    'userID': 'user_id',
    'HTTPServer': 'http_server',
    'IOStream': 'io_stream',
    'URL': 'url',
    'address2Line': 'address2_line',
    'version2': 'version2',
    'already_snake': 'already_snake',
    'Person': 'person',
    r'price$': r'price$',
    'ÄrgerLevel': 'ärger_level',
  };

  test('snake_cases names the way ratel_orm does', () {
    for (final MapEntry(key: name, value: column) in samples.entries) {
      expect(SqlNames.of(name), column, reason: name);
    }
  });

  test('matches the SqlNames of the resolved ratel_orm', () async {
    final workspace = await Directory.systemTemp.createTemp('ratel_sql_names');
    addTearDown(() => workspace.delete(recursive: true));
    final app = await OrmFixture.copy('orm_only', workspace);
    final input = File(p.join(workspace.path, 'names.json'))
      ..writeAsStringSync(jsonEncode(samples.keys.toList()));
    final output = File(p.join(workspace.path, 'columns.json'));
    File(p.join(app.path, 'tool', 'names.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
import 'dart:convert';
import 'dart:io';

import 'package:ratel_orm/src/runtime/sql_names.dart';

void main(List<String> arguments) {
  final names = jsonDecode(File(arguments[0]).readAsStringSync()) as List;
  File(arguments[1]).writeAsStringSync(
    jsonEncode([for (final name in names) SqlNames.of(name as String)]),
  );
}
''');
    final ran = await Process.run(
      DartSdk.dart,
      ['run', p.join('tool', 'names.dart'), input.path, output.path],
      workingDirectory: app.path,
    );
    expect(ran.exitCode, 0, reason: '${ran.stdout}${ran.stderr}');
    expect(
      [for (final name in samples.keys) SqlNames.of(name)],
      jsonDecode(output.readAsStringSync()),
    );
  }, tags: 'orm');
}
