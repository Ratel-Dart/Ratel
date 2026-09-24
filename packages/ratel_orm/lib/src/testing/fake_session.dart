import '../driver/query_result.dart';
import '../driver/ratel_session.dart';
import 'fake_driver.dart';

class FakeSession implements RatelSession {
  final FakeDriver _driver;

  FakeSession(this._driver);

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _driver.query(sql, parameters: parameters);
}
