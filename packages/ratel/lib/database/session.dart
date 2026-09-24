import 'query_result.dart';

abstract class RatelSession {
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters});
}
