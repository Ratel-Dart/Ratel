import '../driver/ratel_driver.dart';
import '../exceptions/mapping_exception.dart';
import '../query/query.dart';

abstract class RatelRepository<T> {
  RatelRepository(this.driver);

  final RatelDriver driver;

  T fromRow(Map<String, Object?> row);

  Future<List<T>?> execute(
    String sql, {
    Map<String, Object?>? parameters,
    bool returning = false,
  }) async {
    final result = await driver.query(
      driver.dialect.applyReturning(sql, returning: returning),
      parameters: parameters,
    );
    if (result.rows.isEmpty) return null;
    return [for (final row in result.rows) _map(row)];
  }

  Future<List<T>?> find(Query query) {
    final built = query.build(driver.dialect);
    return execute(built.sql, parameters: built.parameters);
  }

  T _map(Map<String, Object?> row) {
    try {
      return fromRow(row);
    } catch (error) {
      throw MappingException(
        'Failed to map a row onto $T: $error',
        cause: error,
      );
    }
  }
}
