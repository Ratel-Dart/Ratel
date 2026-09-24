import '../dialect.dart';

String applyReturningClause(String sql) =>
    const PostgresDialect().applyReturning(sql, returning: true);
