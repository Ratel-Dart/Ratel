import 'package:postgres/postgres.dart';
import 'package:ratel/ratel.dart' show QueryResult, RatelSession;

import 'query_result_mapper.dart';

/// A [RatelSession] scoped to an open Postgres transaction.
class PostgresSession implements RatelSession {
  final TxSession _tx;

  /// Wraps the transaction session [_tx].
  PostgresSession(this._tx);

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    final result = (parameters == null || parameters.isEmpty)
        ? await _tx.execute(sql)
        : await _tx.execute(Sql.named(sql), parameters: parameters);
    return toQueryResult(result);
  }
}
