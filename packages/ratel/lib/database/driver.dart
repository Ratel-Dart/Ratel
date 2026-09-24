import 'query_result.dart';
import 'session.dart';

abstract class RatelDriver {
  Future<void> open();

  Future<void> close();

  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters});

  Future<T> transaction<T>(Future<T> Function(RatelSession session) action);
}
