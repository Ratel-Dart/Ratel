import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:test/test.dart';

import '../support/sqlite_test_library.dart';

void main() {
  setUpAll(SqliteTestLibrary.useSystemLibrary);

  group('limitOffset', () {
    test('renders LIMIT -1 before an offset given without a limit', () {
      expect(const SqliteDialect().limitOffset(offset: 2), 'LIMIT -1 OFFSET 2');
    });

    test('keeps an explicit limit and a limit alone unchanged', () {
      expect(
        const SqliteDialect().limitOffset(limit: 10, offset: 20),
        'LIMIT 10 OFFSET 20',
      );
      expect(const SqliteDialect().limitOffset(limit: 5), 'LIMIT 5');
      expect(const SqliteDialect().limitOffset(), '');
    });

    test('a query with only an offset runs on SQLite', () async {
      final driver = SqliteDriver.memory();
      await driver.open();
      await driver.query('CREATE TABLE t (id INTEGER PRIMARY KEY)');
      await driver.query('INSERT INTO t (id) VALUES (1), (2), (3), (4)');

      final built = Query.from('t').orderBy('id').offset(2).build(
            driver.dialect,
          );
      final result = await driver.query(
        built.sql,
        parameters: built.parameters,
      );

      expect(result.rows.map((row) => row['id']).toList(), [3, 4]);
      await driver.close();
    });
  });
}
