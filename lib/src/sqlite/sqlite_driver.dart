import 'package:ratel/ratel.dart'
    show QueryExecutionException, QueryResult, RatelSession;
import 'package:sqlite3/sqlite3.dart';

import '../dialect.dart';
import '../orm_driver.dart';

/// An [OrmDriver] backed by `package:sqlite3` (in-process SQLite).
///
/// Canonical `@name` placeholders are bound natively. SQL runs verbatim when no
/// parameters are supplied.
class SqliteDriver extends OrmDriver {
  /// The database file path, or `:memory:` for an in-memory database.
  final String path;

  Database? _db;

  /// Opens SQLite at [path].
  SqliteDriver(this.path);

  /// A transient in-memory database (handy for tests).
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
      final result = await action(_SqliteSession(this));
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

class _SqliteSession implements RatelSession {
  final SqliteDriver _driver;

  _SqliteSession(this._driver);

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _driver.query(sql, parameters: parameters);
}
