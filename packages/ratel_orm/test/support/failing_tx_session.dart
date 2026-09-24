import 'dart:async';

import 'package:postgres/postgres.dart';

class FailingTxSession implements TxSession {
  FailingTxSession(this.error);

  final Object error;

  @override
  bool get isOpen => true;

  @override
  Future<void> get closed => Completer<void>().future;

  @override
  Future<Statement> prepare(Object query) async => throw error;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async =>
      throw error;

  @override
  Future<void> rollback() async {}
}
