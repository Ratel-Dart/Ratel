import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

void main() {
  group('rewrite placeholders', () {
    test('Postgres and SQLite keep @name (identity)', () {
      const sql = 'SELECT * FROM t WHERE a = @a AND b = @b';
      expect(const PostgresDialect().rewrite(sql, {'a': 1, 'b': 2}).sql, sql);
      expect(const SqliteDialect().rewrite(sql, {'a': 1}).sql, sql);
    });

    test('MySQL translates @name to :name', () {
      final result = const MysqlDialect().rewrite(
        'SELECT * FROM t WHERE a = @a AND b = @b',
        {'a': 1, 'b': 2},
      );
      expect(result.sql, 'SELECT * FROM t WHERE a = :a AND b = :b');
    });

    test('MySQL repeats a placeholder used twice', () {
      final result =
          const MysqlDialect().rewrite('SELECT @x, @x FROM t', {'x': 1});
      expect(result.sql, 'SELECT :x, :x FROM t');
    });

    test('MySQL leaves statements without parameters untouched', () {
      final result = const MysqlDialect().rewrite('SELECT 1', null);
      expect(result.sql, 'SELECT 1');
      expect(result.parameters, isNull);
    });

    test('MySQL does not touch @ inside string literals or operators', () {
      final result = const MysqlDialect().rewrite(
        "SELECT '@notparam', tags @> @filter FROM t -- @comment",
        {'filter': 'x'},
      );
      expect(
          result.sql, "SELECT '@notparam', tags @> :filter FROM t -- @comment");
    });

    test('MySQL ignores @ in a block comment and preserves :: casts', () {
      final result = const MysqlDialect().rewrite(
        'SELECT @id::text /* @skip */ FROM t',
        {'id': 1},
      );
      expect(result.sql, 'SELECT :id::text /* @skip */ FROM t');
    });
  });

  group('applyReturning', () {
    test('Postgres appends RETURNING * to a write when requested', () {
      expect(
        const PostgresDialect()
            .applyReturning('INSERT INTO t (a) VALUES (@a)', returning: true),
        'INSERT INTO t (a) VALUES (@a) RETURNING *',
      );
    });

    test('is a no-op when returning is false', () {
      expect(
        const PostgresDialect()
            .applyReturning('INSERT INTO t (a) VALUES (1)', returning: false),
        'INSERT INTO t (a) VALUES (1)',
      );
    });

    test('MySQL never appends RETURNING (unsupported)', () {
      expect(const MysqlDialect().supportsReturning, isFalse);
      expect(
        const MysqlDialect()
            .applyReturning('INSERT INTO t (a) VALUES (1)', returning: true),
        'INSERT INTO t (a) VALUES (1)',
      );
    });

    test('does not append on SELECT and trims a trailing semicolon', () {
      final dialect = const PostgresDialect();
      expect(dialect.applyReturning('SELECT 1;', returning: true), 'SELECT 1');
      expect(
        dialect.applyReturning('DELETE FROM t;', returning: true),
        'DELETE FROM t RETURNING *',
      );
    });
  });

  group('identifier quoting and upsert', () {
    test('quotes identifiers per engine', () {
      expect(const PostgresDialect().quoteIdentifier('col'), '"col"');
      expect(const SqliteDialect().quoteIdentifier('col'), '"col"');
      expect(const MysqlDialect().quoteIdentifier('col'), '`col`');
    });

    test('Postgres upsert uses ON CONFLICT ... DO UPDATE', () {
      expect(
        const PostgresDialect().upsert(
          table: 'users',
          columns: ['name'],
          conflictKeys: ['id'],
        ),
        'ON CONFLICT ("id") DO UPDATE SET "name" = EXCLUDED."name"',
      );
    });

    test('MySQL upsert uses ON DUPLICATE KEY UPDATE', () {
      expect(
        const MysqlDialect().upsert(
          table: 'users',
          columns: ['name'],
          conflictKeys: ['id'],
        ),
        'ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)',
      );
    });

    test('limitOffset builds the pagination fragment', () {
      expect(
        const StandardDialect().limitOffset(limit: 10, offset: 20),
        'LIMIT 10 OFFSET 20',
      );
      expect(const StandardDialect().limitOffset(limit: 5), 'LIMIT 5');
    });
  });
}
