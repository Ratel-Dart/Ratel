import 'dart:ffi';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

import 'support/conformance.dart';

class Note {
  @Column(name: 'id')
  int id = 0;

  @Column(name: 'body')
  String body = '';
}

class NoteRepo extends RatelRepository<Note> {
  Future<List<Note>?> insert(int id, String body) => execute(
        'INSERT INTO notes (id, body) VALUES (@id, @body)',
        substitutionValues: {'id': id, 'body': body},
        returning: true,
      );

  Future<List<Note>?> all() => execute('SELECT * FROM notes ORDER BY id');
}

void main() {
  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  test('in-memory CRUD via repository with @name params and returning',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    RatelRepository.configure(driver);
    await driver
        .query('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');

    final inserted = await NoteRepo().insert(1, 'hello');
    expect(inserted, isNotNull);
    expect(inserted!.single.id, 1);
    expect(inserted.single.body, 'hello');

    final all = await NoteRepo().all();
    expect(all!.single.body, 'hello');
    await driver.close();
  });

  test('param-less SQL runs verbatim (@ left intact)', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    final result = await driver.query("SELECT '@x' AS v");
    expect(result.rows.single['v'], '@x');
    await driver.close();
  });

  test('transaction commits, and rolls back on error', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    await driver.transaction((session) async {
      await session
          .query('INSERT INTO t (id) VALUES (@id)', parameters: {'id': 1});
      return session.query('SELECT 1');
    });
    var count = await driver.query('SELECT count(*) AS c FROM t');
    expect(count.rows.single['c'], 1);

    await expectLater(
      driver.transaction((session) async {
        await session
            .query('INSERT INTO t (id) VALUES (@id)', parameters: {'id': 2});
        throw StateError('boom');
      }),
      throwsA(isA<StateError>()),
    );
    count = await driver.query('SELECT count(*) AS c FROM t');
    expect(count.rows.single['c'], 1);
    await driver.close();
  });

  group('driver conformance', () {
    runDriverConformanceTests(SqliteDriver.memory);
  });
}
