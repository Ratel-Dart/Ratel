import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

void main() {
  group('applyReturning', () {
    test('appends RETURNING * to INSERT, UPDATE and DELETE when requested', () {
      const dialect = PostgresDialect();
      expect(
        dialect.applyReturning('INSERT INTO t (a) VALUES (@a)',
            returning: true),
        'INSERT INTO t (a) VALUES (@a) RETURNING *',
      );
      expect(
        dialect.applyReturning('UPDATE t SET a = 1', returning: true),
        'UPDATE t SET a = 1 RETURNING *',
      );
      expect(
        dialect.applyReturning('DELETE FROM t WHERE a = 1', returning: true),
        'DELETE FROM t WHERE a = 1 RETURNING *',
      );
    });

    test('is a no-op when returning is false', () {
      expect(
        const PostgresDialect()
            .applyReturning('INSERT INTO t (a) VALUES (1)', returning: false),
        'INSERT INTO t (a) VALUES (1)',
      );
    });

    test('does not duplicate an existing RETURNING', () {
      expect(
        const PostgresDialect().applyReturning(
          'INSERT INTO t (a) VALUES (1) RETURNING id',
          returning: true,
        ),
        'INSERT INTO t (a) VALUES (1) RETURNING id',
      );
    });

    test('appends when returning only appears inside a longer identifier', () {
      const dialect = PostgresDialect();
      expect(
        dialect.applyReturning(
          'UPDATE orders SET returning_customer = 1',
          returning: true,
        ),
        'UPDATE orders SET returning_customer = 1 RETURNING *',
      );
      expect(
        dialect.applyReturning(
          'INSERT INTO orders (is_returning) VALUES (@r)',
          returning: true,
        ),
        'INSERT INTO orders (is_returning) VALUES (@r) RETURNING *',
      );
    });

    test('appends when returning only appears inside quotes', () {
      const dialect = PostgresDialect();
      expect(
        dialect.applyReturning(
          "INSERT INTO notes (body) VALUES ('it''s returning soon')",
          returning: true,
        ),
        "INSERT INTO notes (body) VALUES ('it''s returning soon') RETURNING *",
      );
      expect(
        dialect.applyReturning(
          'UPDATE t SET "returning" = 1',
          returning: true,
        ),
        'UPDATE t SET "returning" = 1 RETURNING *',
      );
    });

    test('recognizes an existing lowercase returning clause', () {
      expect(
        const PostgresDialect().applyReturning(
          "DELETE FROM t WHERE note = 'x' returning id",
          returning: true,
        ),
        "DELETE FROM t WHERE note = 'x' returning id",
      );
    });

    test('does not append on SELECT and trims a trailing semicolon', () {
      const dialect = PostgresDialect();
      expect(dialect.applyReturning('SELECT 1;', returning: true), 'SELECT 1');
      expect(
        dialect.applyReturning('DELETE FROM t;', returning: true),
        'DELETE FROM t RETURNING *',
      );
    });
  });

  group('identifiers and pagination', () {
    test('quotes identifiers with double quotes', () {
      expect(const PostgresDialect().quoteIdentifier('col'), '"col"');
      expect(const SqliteDialect().quoteIdentifier('col'), '"col"');
    });

    test('limitOffset builds the pagination fragment', () {
      expect(
        const StandardDialect().limitOffset(limit: 10, offset: 20),
        'LIMIT 10 OFFSET 20',
      );
      expect(const StandardDialect().limitOffset(limit: 5), 'LIMIT 5');
    });

    test('Postgres keeps OFFSET alone without a limit', () {
      expect(const PostgresDialect().limitOffset(offset: 20), 'OFFSET 20');
    });
  });
}
