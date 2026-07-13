import 'package:ratel/ratel.dart' show RatelDriver;
import 'package:ratel_orm/postgres.dart';
import 'package:test/test.dart';

void main() {
  group('applyReturningClause', () {
    test('appends RETURNING * to INSERT/UPDATE/DELETE', () {
      expect(applyReturningClause('INSERT INTO t (a) VALUES (1)'),
          'INSERT INTO t (a) VALUES (1) RETURNING *');
      expect(applyReturningClause('UPDATE t SET a = 1'),
          'UPDATE t SET a = 1 RETURNING *');
      expect(applyReturningClause('DELETE FROM t WHERE a = 1'),
          'DELETE FROM t WHERE a = 1 RETURNING *');
    });

    test('leaves SELECT untouched', () {
      expect(applyReturningClause('SELECT * FROM t'), 'SELECT * FROM t');
    });

    test('does not duplicate an existing RETURNING', () {
      expect(applyReturningClause('INSERT INTO t (a) VALUES (1) RETURNING id'),
          'INSERT INTO t (a) VALUES (1) RETURNING id');
    });

    test('trims a trailing semicolon', () {
      expect(
          applyReturningClause('DELETE FROM t;'), 'DELETE FROM t RETURNING *');
      expect(applyReturningClause('SELECT 1;'), 'SELECT 1');
    });
  });

  group('PostgresDriver', () {
    test('is a RatelDriver', () {
      final driver = PostgresDriver(
        host: 'localhost',
        databaseName: 'app',
        username: 'user',
        password: 'secret',
      );
      expect(driver, isA<RatelDriver>());
      expect(driver.port, 5432);
      expect(driver.sslMode, SslMode.require);
    });

    test('open and close are no-ops before pooling lands', () async {
      final driver = PostgresDriver(
        host: 'localhost',
        databaseName: 'app',
        username: 'user',
        password: 'secret',
      );
      await driver.open();
      await driver.close();
    });
  });
}
