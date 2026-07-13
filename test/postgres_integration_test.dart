import 'dart:io';

import 'package:ratel_orm/postgres.dart';
import 'package:test/test.dart';

void main() {
  final env = Platform.environment;
  final skip = env['DB_HOST'] == null
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
      expect(inserted.rows.single['id'], 1);
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
  });
}
