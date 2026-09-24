import 'standard_dialect.dart';

class SqliteDialect extends StandardDialect {
  const SqliteDialect();

  @override
  String limitOffset({int? limit, int? offset}) => super.limitOffset(
        limit: limit ?? (offset == null ? null : -1),
        offset: offset,
      );
}
