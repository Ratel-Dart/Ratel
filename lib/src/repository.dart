import 'dart:mirrors';

import 'package:ratel/ratel.dart' show Db, QueryResult, RatelDriver;

import 'annotations.dart';
import 'exceptions.dart';
import 'orm_driver.dart';

/// Base class for data-access repositories of entity type [T].
///
/// Subclasses call [execute] with a SQL statement; result rows are mapped onto
/// [T] using its [Column]-annotated fields. The driver is read from the core
/// [Db] registry, the single source of truth shared with the raw-SQL facade.
abstract class RatelRepository<T> {
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

  T _mapRow(Map<String, Object?> row) =>
      _generateFromRow(reflectClass(T), row) as T;
}

dynamic _generateFromRow(ClassMirror typeMirror, Map<String, Object?> row) {
  final instance = typeMirror.newInstance(const Symbol(''), const []);
  typeMirror.declarations.forEach((symbol, decl) {
    if (decl is VariableMirror && !decl.isStatic) {
      final columns = decl.metadata.where((meta) => meta.reflectee is Column);
      if (columns.isNotEmpty) {
        final column = columns.first.reflectee as Column;
        final field = MirrorSystem.getName(symbol);
        final key = column.name.isNotEmpty
            ? column.name.toLowerCase()
            : field.toLowerCase();
        if (row.containsKey(key)) {
          try {
            instance.setField(symbol, row[key]);
          } catch (e) {
            final entity = MirrorSystem.getName(typeMirror.simpleName);
            throw MappingException(
              'Cannot map column "$key" onto $entity.$field: $e',
            );
          }
        }
      }
    }
  });
  return instance.reflectee;
}
