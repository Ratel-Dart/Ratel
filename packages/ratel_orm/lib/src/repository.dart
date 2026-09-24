import 'package:ratel/ratel.dart' show Db, QueryResult, RatelDriver;

import 'dialect.dart';
import 'exceptions.dart';
import 'orm_driver.dart';
import 'query.dart';
import 'row_mappers.dart';

abstract class RatelRepository<T> {
  final T Function(Map<String, Object?> row)? _explicitFromRow;

  RatelRepository([this._explicitFromRow]);

  late final T Function(Map<String, Object?> row) _fromRow =
      _explicitFromRow ?? RatelRowMappers.of<T>();

  static void configure(RatelDriver driver) => Db.configure(driver);

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
