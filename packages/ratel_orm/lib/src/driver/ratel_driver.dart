import '../dialect/sql_dialect.dart';
import 'query_result.dart';
import 'ratel_session.dart';

abstract class RatelDriver {
  SqlDialect get dialect;

  Future<void> open();

  Future<void> close();

  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters});

  Future<T> transaction<T>(Future<T> Function(RatelSession session) action);
}
