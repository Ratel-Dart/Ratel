import 'dart:async';
import 'dart:io';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
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

  test('a SELECT after a write reports no affected rows and no insert id',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    final insert = await driver
        .query('INSERT INTO t (id) VALUES (@id)', parameters: {'id': 7});
    expect(insert.affectedRows, 1);
    expect(insert.lastInsertId, 7);

    final select = await driver.query('SELECT id FROM t');
    expect(select.rows.single['id'], 7);
    expect(select.affectedRows, 0);
    expect(select.lastInsertId, isNull);

    final bound = await driver
        .query('SELECT id FROM t WHERE id = @id', parameters: {'id': 7});
    expect(bound.rows.single['id'], 7);
    expect(bound.affectedRows, 0);
    expect(bound.lastInsertId, isNull);
    await driver.close();
  });

  test('a driver query waits for an open transaction instead of joining it',
      () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');

    final entered = Completer<void>();
    final release = Completer<void>();
    final transaction = driver.transaction((session) async {
      await session.query('INSERT INTO t (id) VALUES (1)');
      entered.complete();
      await release.future;
      throw StateError('rollback');
    });
    await entered.future;

    final outside = driver.query('INSERT INTO t (id) VALUES (2)');
    release.complete();
    await expectLater(transaction, throwsA(isA<StateError>()));
    await outside;

    final ids = await driver.query('SELECT id FROM t ORDER BY id');
    expect([for (final row in ids.rows) row['id']], [2]);
    await driver.close();
  });

  test('a driver query made inside a transaction runs in it', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver
        .query('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');
    final notes = NoteRepository(driver);

    final seen = await driver.transaction((session) async {
      await session.query("INSERT INTO notes (id, body) VALUES (1, 'draft')");
      return notes.all();
    }).timeout(const Duration(seconds: 5));

    expect(seen!.single.body, 'draft');
    await driver.close();
  });

  test('open wraps a native failure in DriverConnectionException', () async {
    final root = await Directory.systemTemp.createTemp('ratel_orm_sqlite_');
    addTearDown(() => root.delete(recursive: true));
    final separator = Platform.pathSeparator;
    final driver =
        SqliteDriver('${root.path}${separator}missing${separator}a.db');

    await expectLater(
      driver.open(),
      throwsA(isA<DriverConnectionException>().having(
        (e) => e.cause,
        'cause',
        isA<SqliteException>(),
      )),
    );
  });

  group('driver conformance', () {
    DriverConformance.run(SqliteDriver.memory);
  });
}
