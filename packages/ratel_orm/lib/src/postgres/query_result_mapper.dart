import 'package:postgres/postgres.dart';
import 'package:ratel/ratel.dart' show QueryResult;

QueryResult toQueryResult(Result result) => QueryResult(
      rows: [for (final row in result) row.toColumnMap()],
      affectedRows: result.affectedRows,
    );
