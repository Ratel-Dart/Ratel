import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

void main() {
  test('QueryExecutionException carries sql and cause', () {
    const error =
        QueryExecutionException('boom', sql: 'SELECT 1', cause: 'root');
    expect(error, isA<DatabaseException>());
    expect(error.sql, 'SELECT 1');
    expect(error.cause, 'root');
    expect(error.toString(), contains('boom'));
  });

  test('every database error is a DatabaseException', () {
    expect(const DriverConnectionException('x'), isA<DatabaseException>());
    expect(const MappingException('x'), isA<DatabaseException>());
  });

  test('MappingException keeps the error that broke the mapping', () {
    const error = MappingException('bad row', cause: 'TypeError');
    expect(error.cause, 'TypeError');
  });
}
