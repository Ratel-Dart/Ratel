import 'package:ratel_orm/sqlite.dart';
import 'package:test/test.dart';

import '../support/driver_conformance.dart';
import '../support/fixtures/repositories/note_repository.dart';
import '../support/sqlite_test_library.dart';

void main() {
  setUpAll(SqliteTestLibrary.useSystemLibrary);

  test('in-memory CRUD via repository with @name params and returning',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver
        .query('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');

    final notes = NoteRepository(driver);
    final inserted = await notes.insert(1, 'hello');
    expect(inserted, isNotNull);
    expect(inserted!.single.id, 1);
    expect(inserted.single.body, 'hello');

    final all = await notes.all();
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
    DriverConformance.run(SqliteDriver.memory);
  });
}
