import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/project/project_scaffold.dart';
import 'package:test/test.dart';

void main() {
  late Directory app;

  setUpAll(() async {
    final parent = await Directory.systemTemp.createTemp('ratel_scaffold');
    addTearDown(() => parent.delete(recursive: true));
    app = Directory(p.join(parent.path, 'My-App'));
    ProjectScaffold.create(app, '2.0.0-dev.8');
  });

  List<File> files() =>
      app.listSync(recursive: true).whereType<File>().toList();

  test('writes a pubspec without code generation dependencies', () {
    final pubspec = File(p.join(app.path, 'pubspec.yaml')).readAsStringSync();
    expect(pubspec, contains('name: my_app'));
    expect(pubspec, contains('ratel: ^2.0.0-dev.8'));
    expect(pubspec, isNot(contains('build_runner')));
    expect(pubspec, isNot(contains('ratel_generator')));
  });

  test('keeps the model and the controller in their own files', () {
    final relative = files()
        .map((file) => p.split(p.relative(file.path, from: app.path)).join('/'))
        .toSet();
    expect(
      relative,
      containsAll([
        'lib/models/greeting.dart',
        'lib/controllers/hello_controller.dart',
        'bin/server.dart',
      ]),
    );
  });

  test('writes no comments in any language', () {
    for (final file in files()) {
      final text = file.readAsStringSync();
      if (file.path.endsWith('.dart')) {
        final unit = parseString(content: text).unit;
        Token? token = unit.beginToken;
        while (token != null && token.type != TokenType.EOF) {
          expect(token.precedingComments, isNull, reason: file.path);
          token = token.next;
        }
      } else if (!file.path.endsWith('.md')) {
        expect(
          text.split('\n').where((line) => line.trimLeft().startsWith('#')),
          isEmpty,
          reason: file.path,
        );
      }
    }
  });

  test('gives every Dart file a single declaration', () {
    for (final file in files().where((file) => file.path.endsWith('.dart'))) {
      final unit = parseString(content: file.readAsStringSync()).unit;
      expect(unit.declarations, hasLength(1), reason: file.path);
    }
  });
}
