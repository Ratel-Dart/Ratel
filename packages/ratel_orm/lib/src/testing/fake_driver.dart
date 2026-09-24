import 'package:ratel/ratel.dart'
    show DatabaseException, QueryResult, RatelDriver, RatelSession;

import 'fake_session.dart';

class FakeDriver extends RatelDriver {
  bool opened = false;

  bool closed = false;

  String? lastSql;

  Map<String, Object?>? lastParameters;

  DatabaseException? errorToThrow;

  final List<QueryResult> _queued = [];

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
