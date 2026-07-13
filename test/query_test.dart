import 'dart:ffi';

import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

part 'query_test.g.dart';

class Person {
  @Column(name: 'id')
  int id = 0;

  @Column(name: 'name')
  String name = '';

  @Column(name: 'age')
  int age = 0;
}

class PersonRepo extends RatelRepository<Person> {
  PersonRepo() : super(_$PersonFromRow);
}

void main() {
  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

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

    test('MySQL quotes identifiers with backticks', () {
      final built =
          Query.from('users').where('id', '=', 1).build(const MysqlDialect());
      expect(built.sql, 'SELECT * FROM `users` WHERE `id` = @p0');
      expect(built.parameters, {'p0': 1});
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
    RatelRepository.configure(driver);
    await driver.query(
      'CREATE TABLE person (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)',
    );
    await driver
        .query("INSERT INTO person (id, name, age) VALUES (1, 'ann', 30)");
    await driver
        .query("INSERT INTO person (id, name, age) VALUES (2, 'bob', 20)");
    await driver
        .query("INSERT INTO person (id, name, age) VALUES (3, 'cid', 40)");

    final adults = await PersonRepo()
        .find(Query.from('person').where('age', '>=', 30).orderBy('name'));

    expect(adults, isNotNull);
    expect(adults!.map((p) => p.name).toList(), ['ann', 'cid']);
    expect(adults.map((p) => p.age).toList(), [30, 40]);
    await driver.close();
  });
}
