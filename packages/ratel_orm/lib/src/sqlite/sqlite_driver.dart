import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

import '../dialect/sql_dialect.dart';
import '../dialect/sqlite_dialect.dart';
import '../driver/query_result.dart';
import '../driver/ratel_driver.dart';
import '../driver/ratel_session.dart';
import '../exceptions/driver_connection_exception.dart';
import '../exceptions/query_execution_exception.dart';
import 'sqlite_session.dart';

class SqliteDriver extends RatelDriver {
  final String path;

  Database? _db;

  Future<void> _idle = Future<void>.value();

  static final Object _holder = Object();

  SqliteDriver(this.path);

  factory SqliteDriver.memory() => SqliteDriver(':memory:');

  @override
  SqlDialect get dialect => const SqliteDialect();

  Database get _database =>
      _db ?? (throw StateError('SqliteDriver has not been opened.'));

  @override
  Future<void> open() async {
    try {
      _db ??= sqlite3.open(path);
    } on SqliteException catch (e) {
      throw DriverConnectionException(
        'SQLite could not open "$path"',
        cause: e,
      );
    }
  }

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _exclusive(() => _execute(sql, parameters: parameters));

  @override
  Future<T> transaction<T>(
    Future<T> Function(RatelSession session) action,
  ) =>
      _exclusive(() async {
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
          final result = await action(SqliteSession(_execute));
          db.execute('COMMIT');
          return result;
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<T> _exclusive<T>(Future<T> Function() body) {
    if (identical(Zone.current[_holder], this)) return body();
    final previous = _idle;
    final released = Completer<void>();
    _idle = released.future;
    return previous
        .then((_) => runZoned(body, zoneValues: {_holder: this}))
        .whenComplete(released.complete);
  }

  Future<QueryResult> _execute(String sql,
      {Map<String, Object?>? parameters}) async {
    final db = _database;
    try {
      final statement = db.prepare(sql);
      try {
        final resultSet = parameters == null || parameters.isEmpty
            ? statement.select()
            : statement.selectWith(StatementParameters.named({
                for (final entry in parameters.entries)
                  '@${entry.key}': entry.value,
              }));
        final wrote = !statement.isReadOnly;
        return QueryResult(
          rows: [for (final row in resultSet) Map<String, Object?>.from(row)],
          affectedRows: wrote ? db.updatedRows : 0,
          lastInsertId: wrote ? db.lastInsertRowId : null,
        );
      } finally {
        statement.dispose();
      }
    } on SqliteException catch (e) {
      throw QueryExecutionException('SQLite query failed', sql: sql, cause: e);
    }
  }
}
