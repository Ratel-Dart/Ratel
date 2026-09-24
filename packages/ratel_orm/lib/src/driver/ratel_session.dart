import 'query_result.dart';

abstract interface class RatelSession {
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters});
}
