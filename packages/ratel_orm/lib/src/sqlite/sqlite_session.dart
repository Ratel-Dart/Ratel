import '../driver/query_result.dart';
import '../driver/ratel_session.dart';
import 'sqlite_driver.dart';

class SqliteSession implements RatelSession {
  final SqliteDriver _driver;

  SqliteSession(this._driver);

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _driver.query(sql, parameters: parameters);
}
