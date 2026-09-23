import 'package:ratel/ratel.dart'
    show DatabaseException, QueryResult, RatelDriver, RatelSession;

import 'fake_session.dart';

/// An in-memory [RatelDriver] for tests.
///
/// Programmable: enqueue results with [enqueue] / [enqueueRows], inspect the
/// last call via [lastSql] / [lastParameters], and force an error with
/// [errorToThrow]. Does not import `package:test`, so it is safe to ship.
class FakeDriver extends RatelDriver {
  /// Whether [open] has been called.
  bool opened = false;

  /// Whether [close] has been called.
  bool closed = false;

  /// The SQL of the most recent [query] call.
  String? lastSql;

  /// The parameters of the most recent [query] call.
  Map<String, Object?>? lastParameters;

  /// When set, the next [query] throws this error.
  DatabaseException? errorToThrow;

  final List<QueryResult> _queued = [];

  /// Queues [result] to be returned by the next [query].
  void enqueue(QueryResult result) => _queued.add(result);

  /// Queues [rows] (wrapped in a [QueryResult]) for the next [query].
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
