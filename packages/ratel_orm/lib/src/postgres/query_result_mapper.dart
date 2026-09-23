import 'package:postgres/postgres.dart';
import 'package:ratel/ratel.dart' show QueryResult;

/// Converts a `package:postgres` [Result] into the driver-contract
/// [QueryResult] shared by every engine.
QueryResult toQueryResult(Result result) => QueryResult(
      rows: [for (final row in result) row.toColumnMap()],
      affectedRows: result.affectedRows,
    );
