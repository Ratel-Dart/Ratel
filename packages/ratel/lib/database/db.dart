import 'driver.dart';
import 'exceptions.dart';
import 'query_result.dart';
import 'session.dart';

class Db {
  static RatelDriver? _ambient;

  final RatelDriver? _driver;

  const Db([RatelDriver? driver]) : _driver = driver;

  static void configure(RatelDriver driver) => _ambient = driver;

  static RatelDriver get driver =>
      _ambient ?? (throw const DatabaseNotConfiguredException());

  RatelDriver get _resolved => _driver ?? driver;

  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _resolved.query(sql, parameters: parameters);

  Future<T> transaction<T>(Future<T> Function(RatelSession session) action) =>
      _resolved.transaction(action);
}
