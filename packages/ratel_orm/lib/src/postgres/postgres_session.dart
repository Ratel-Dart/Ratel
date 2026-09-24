import 'package:postgres/postgres.dart';

import '../driver/query_result.dart';
import '../driver/ratel_session.dart';
import 'postgres_result_mapper.dart';

class PostgresSession implements RatelSession {
  final TxSession _tx;

  PostgresSession(this._tx);

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    final result = (parameters == null || parameters.isEmpty)
        ? await _tx.execute(sql)
        : await _tx.execute(Sql.named(sql), parameters: parameters);
    return PostgresResultMapper.toQueryResult(result);
  }
}
