import 'package:postgres/postgres.dart';

import '../driver/query_result.dart';

abstract final class PostgresResultMapper {
  static QueryResult toQueryResult(Result result) => QueryResult(
        rows: [for (final row in result) row.toColumnMap()],
        affectedRows: result.affectedRows,
      );
}
