import 'package:ratel/ratel.dart' show QueryResult, RatelDriver;

import '../dialect.dart';
import '../exceptions.dart';
import '../orm_driver.dart';
import '../query.dart';

abstract class RatelRepository<T> {
  RatelRepository(this.driver);

  final RatelDriver driver;

  T fromRow(Map<String, Object?> row);

  Future<List<T>?> execute(
    String sql, {
    Map<String, Object?>? parameters,
    bool returning = false,
  }) async {
    final current = driver;
    final finalSql = current is OrmDriver
        ? current.dialect.applyReturning(sql, returning: returning)
        : sql;
    final QueryResult result =
        await current.query(finalSql, parameters: parameters);
    if (result.rows.isEmpty) return null;
    return [for (final row in result.rows) _map(row)];
  }

  Future<List<T>?> find(Query query) {
    final current = driver;
    final dialect =
        current is OrmDriver ? current.dialect : const StandardDialect();
    final built = query.build(dialect);
    return execute(built.sql, parameters: built.parameters);
  }

  T _map(Map<String, Object?> row) {
    try {
      return fromRow(row);
    } catch (error) {
      throw MappingException('Failed to map a row onto $T: $error');
    }
  }
}
