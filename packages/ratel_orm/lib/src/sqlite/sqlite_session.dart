import '../driver/query_result.dart';
import '../driver/ratel_session.dart';

class SqliteSession implements RatelSession {
  final Future<QueryResult> Function(
    String sql, {
    Map<String, Object?>? parameters,
  }) _execute;

  SqliteSession(this._execute);

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _execute(sql, parameters: parameters);
}
