import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:test/test.dart';

import '../support/fixtures/repositories/person_repository.dart';
import '../support/sqlite_test_library.dart';

void main() {
  setUpAll(SqliteTestLibrary.useSystemLibrary);

  group('build', () {
    test('Postgres quotes identifiers and parameterizes values', () {
      final built = Query.from('users')
          .select(['id', 'name'])
          .where('age', '>', 18)
          .orderBy('name')
          .limit(10)
          .offset(5)
          .build(const PostgresDialect());
      expect(
        built.sql,
        'SELECT "id", "name" FROM "users" WHERE "age" > @p0 '
        'ORDER BY "name" ASC LIMIT 10 OFFSET 5',
      );
      expect(built.parameters, {'p0': 18});
    });

    test('combines AND/OR conditions in order', () {
      final built = Query.from('t')
          .where('a', '=', 1)
          .orWhere('b', '=', 2)
          .where('c', '>', 3)
          .build(const PostgresDialect());
      expect(
        built.sql,
        'SELECT * FROM "t" WHERE "a" = @p0 OR "b" = @p1 AND "c" > @p2',
      );
      expect(built.parameters, {'p0': 1, 'p1': 2, 'p2': 3});
    });
  });

  test('runs a built query end-to-end via repository.find (SQLite)', () async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await driver.query(
      'CREATE TABLE person (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)',
    );
    await driver
        .query("INSERT INTO person (id, name, age) VALUES (1, 'ann', 30)");
    await driver
        .query("INSERT INTO person (id, name, age) VALUES (2, 'bob', 20)");
    await driver
        .query("INSERT INTO person (id, name, age) VALUES (3, 'cid', 40)");

    final adults = await PersonRepository(driver)
        .find(Query.from('person').where('age', '>=', 30).orderBy('name'));

    expect(adults, isNotNull);
    expect(adults!.map((p) => p.name).toList(), ['ann', 'cid']);
    expect(adults.map((p) => p.age).toList(), [30, 40]);
    await driver.close();
  });
}
