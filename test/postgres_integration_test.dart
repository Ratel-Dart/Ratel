import 'dart:io';

import 'package:ratel_orm/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

part 'postgres_integration_test.g.dart';

class Widget {
  @Column(name: 'id')
  int id = 0;

  @Column(name: 'label')
  String label = '';
}

class WidgetRepo extends RatelRepository<Widget> {
  WidgetRepo() : super(_$WidgetFromRow);

  Future<List<Widget>?> insert(int id, String label) => execute(
        'INSERT INTO ratel_repo_widgets (id, label) VALUES (@id, @label)',
        substitutionValues: {'id': id, 'label': label},
        returning: true,
      );
}

void main() {
  final skip = Platform.environment['DB_HOST'] == null
      ? 'set DB_HOST/DB_NAME/DB_USER/DB_PASSWORD to run the Postgres integration'
      : false;

  group('PostgresDriver against a live server', () {
    test('runs DDL, parameterized CRUD and a transaction', () async {
      final driver = PostgresDriver.fromEnv();
      await driver.open();

      await driver.query('DROP TABLE IF EXISTS ratel_widgets');
      await driver.query(
        'CREATE TABLE ratel_widgets (id int PRIMARY KEY, name text)',
      );

      final inserted = await driver.query(
        'INSERT INTO ratel_widgets (id, name) VALUES (@id, @name) RETURNING *',
        parameters: {'id': 1, 'name': 'alpha'},
      );
      expect(inserted.rows.single['name'], 'alpha');

      final selected = await driver.query(
        'SELECT * FROM ratel_widgets WHERE id = @id',
        parameters: {'id': 1},
      );
      expect(selected.rows.single['name'], 'alpha');

      final updated = await driver.query(
        'UPDATE ratel_widgets SET name = @name WHERE id = @id',
        parameters: {'name': 'beta', 'id': 1},
      );
      expect(updated.affectedRows, 1);

      final count = await driver.transaction((session) async {
        await session.query(
          'INSERT INTO ratel_widgets (id, name) VALUES (@id, @name)',
          parameters: {'id': 2, 'name': 'gamma'},
        );
        return session.query('SELECT count(*) AS total FROM ratel_widgets');
      });
      expect(count.rows.single['total'], 2);

      await driver.query('DROP TABLE ratel_widgets');
      await driver.close();
    }, skip: skip);

    test('RatelRepository maps rows and honours returning:', () async {
      final driver = PostgresDriver.fromEnv();
      await driver.open();
      RatelRepository.configure(driver);

      await driver.query('DROP TABLE IF EXISTS ratel_repo_widgets');
      await driver.query(
        'CREATE TABLE ratel_repo_widgets (id int PRIMARY KEY, label text)',
      );

      final rows = await WidgetRepo().insert(7, 'omega');
      expect(rows, isNotNull);
      expect(rows!.single.id, 7);
      expect(rows.single.label, 'omega');

      await driver.query('DROP TABLE ratel_repo_widgets');
      await driver.close();
    }, skip: skip);
  });
}
