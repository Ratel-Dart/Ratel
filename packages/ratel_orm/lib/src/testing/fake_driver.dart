import '../dialect/sql_dialect.dart';
import '../dialect/standard_dialect.dart';
import '../driver/query_result.dart';
import '../driver/ratel_driver.dart';
import '../driver/ratel_session.dart';
import '../exceptions/database_exception.dart';
import 'fake_session.dart';

class FakeDriver extends RatelDriver {
  bool opened = false;

  bool closed = false;

  String? lastSql;

  Map<String, Object?>? lastParameters;

  DatabaseException? errorToThrow;

  final List<QueryResult> _queued = [];

  @override
  SqlDialect get dialect => const StandardDialect();

  void enqueue(QueryResult result) => _queued.add(result);

  void enqueueRows(List<Map<String, Object?>> rows) =>
      _queued.add(QueryResult(rows: rows));

  @override
  Future<void> open() async => opened = true;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    lastSql = sql;
    lastParameters = parameters;
    if (errorToThrow != null) throw errorToThrow!;
    return _queued.isNotEmpty ? _queued.removeAt(0) : const QueryResult();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(RatelSession session) action) =>
      action(FakeSession(this));
}
