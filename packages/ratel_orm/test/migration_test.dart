import 'dart:ffi';

import 'package:ratel/ratel.dart' show QueryExecutionException;
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  test('applies pending migrations in order and is idempotent', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    final migrator = Migrator(driver);
    final migrations = [
      const Migration(
        id: '0002_index',
        up: ['CREATE INDEX idx_notes_body ON notes (body)'],
      ),
      const Migration(
        id: '0001_notes',
        up: ['CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)'],
      ),
    ];

    final firstRun = await migrator.migrate(migrations);
    expect(firstRun, ['0001_notes', '0002_index']);

    await driver.query("INSERT INTO notes (id, body) VALUES (1, 'x')");
    final rows = await driver.query('SELECT * FROM notes');
    expect(rows.rows.single['body'], 'x');

    final secondRun = await migrator.migrate(migrations);
    expect(secondRun, isEmpty);
    expect(await migrator.appliedIds(), {'0001_notes', '0002_index'});

    await driver.close();
  });

  test('a failing migration rolls back and is not recorded', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    final migrator = Migrator(driver);
    final migrations = [
      const Migration(
        id: '0001_ok',
        up: ['CREATE TABLE t (id INTEGER PRIMARY KEY)'],
      ),
      const Migration(
        id: '0002_bad',
        up: [
          'CREATE TABLE t2 (id INTEGER PRIMARY KEY)',
          'THIS IS NOT VALID SQL',
        ],
      ),
    ];

    await expectLater(
      migrator.migrate(migrations),
      throwsA(isA<QueryExecutionException>()),
    );

    expect(await migrator.appliedIds(), {'0001_ok'});
    await expectLater(
      driver.query('SELECT * FROM t2'),
      throwsA(isA<QueryExecutionException>()),
    );

    await driver.close();
  });
}
