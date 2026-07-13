import 'package:ratel/ratel.dart' show Db, QueryResult, RatelDriver;

import 'dialect.dart';
import 'exceptions.dart';
import 'orm_driver.dart';
import 'query.dart';

/// Base class for data-access repositories of entity type [T].
///
/// Subclasses pass a generated `fromRow` mapper (`_$<Name>FromRow`) to the
/// constructor; [execute] runs a SQL statement and maps each result row onto
/// [T] with it. The driver is read from the core [Db] registry, the single
/// source of truth shared with the raw-SQL facade.
abstract class RatelRepository<T> {
  final T Function(Map<String, Object?> row) _fromRow;

  /// Creates a repository that maps rows with [fromRow] (generated from the
  /// entity's `@Column` fields).
  RatelRepository(this._fromRow);

  /// Registers [driver] for standalone use (without a running server).
  ///
  /// Delegates to the core registry so repositories and the raw-SQL facade
  /// share one driver.
  static void configure(RatelDriver driver) => Db.configure(driver);

  /// Runs [sql] with optional [substitutionValues] and maps the rows onto [T].
  ///
  /// Set [returning] to append the engine's returning clause (e.g. Postgres
  /// `RETURNING *`) so a write echoes the affected rows back; it is a no-op on
  /// engines that do not support it.
  ///
  /// Returns null when the statement produces no rows. Driver errors
  /// ([DatabaseException]) propagate unchanged; a row that cannot be mapped
  /// raises a [MappingException].
  Future<List<T>?> execute(
    String sql, {
    Map<String, Object?>? substitutionValues,
    bool returning = false,
  }) async {
    final driver = Db.driver;
    final finalSql = driver is OrmDriver
        ? driver.dialect.applyReturning(sql, returning: returning)
        : sql;
    final QueryResult result =
        await driver.query(finalSql, parameters: substitutionValues);
    if (result.rows.isEmpty) return null;
    return [for (final row in result.rows) _mapRow(row)];
  }

  /// Builds [query] for the configured driver's dialect, runs it and maps the
  /// rows onto [T].
  Future<List<T>?> find(Query query) {
    final driver = Db.driver;
    final dialect =
        driver is OrmDriver ? driver.dialect : const StandardDialect();
    final built = query.build(dialect);
    return execute(built.sql, substitutionValues: built.parameters);
  }

  T _mapRow(Map<String, Object?> row) {
    try {
      return _fromRow(row);
    } catch (e) {
      throw MappingException('Failed to map a row onto $T: $e');
    }
  }
}
