import 'package:sqlite3/sqlite3.dart';

import '../dialect/sql_dialect.dart';
import '../dialect/sqlite_dialect.dart';
import '../driver/query_result.dart';
import '../driver/ratel_driver.dart';
import '../driver/ratel_session.dart';
import '../exceptions/query_execution_exception.dart';
import 'sqlite_session.dart';

class SqliteDriver extends RatelDriver {
  final String path;

  Database? _db;

  SqliteDriver(this.path);

  factory SqliteDriver.memory() => SqliteDriver(':memory:');

  @override
  SqlDialect get dialect => const SqliteDialect();

  Database get _database =>
      _db ?? (throw StateError('SqliteDriver has not been opened.'));

  @override
  Future<void> open() async => _db ??= sqlite3.open(path);

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    final db = _database;
    try {
      final ResultSet resultSet;
      if (parameters == null || parameters.isEmpty) {
        resultSet = db.select(sql);
      } else {
        final statement = db.prepare(sql);
        try {
          final named = {
            for (final entry in parameters.entries)
              '@${entry.key}': entry.value,
          };
          resultSet = statement.selectWith(StatementParameters.named(named));
        } finally {
          statement.dispose();
        }
      }
      return QueryResult(
        rows: [for (final row in resultSet) Map<String, Object?>.from(row)],
        affectedRows: db.updatedRows,
        lastInsertId: db.lastInsertRowId,
      );
    } on SqliteException catch (e) {
      throw QueryExecutionException('SQLite query failed', sql: sql, cause: e);
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(RatelSession session) action,
  ) async {
    final db = _database;
    try {
      db.execute('BEGIN');
    } on SqliteException catch (e) {
      throw QueryExecutionException(
        'SQLite transaction failed',
        sql: 'BEGIN',
        cause: e,
      );
    }
    try {
      final result = await action(SqliteSession(this));
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
