import 'package:postgres/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/src/postgres/postgres_session.dart';
import 'package:test/test.dart';

import '../support/failing_tx_session.dart';

void main() {
  group('PostgresSession', () {
    test('wraps a database error in a QueryExecutionException with the SQL',
        () async {
      final error = PgException('relation "missing" does not exist');
      final session = PostgresSession(FailingTxSession(error));

      await expectLater(
        session.query('SELECT * FROM missing'),
        throwsA(
          isA<QueryExecutionException>()
              .having((e) => e.sql, 'sql', 'SELECT * FROM missing')
              .having((e) => e.cause, 'cause', same(error)),
        ),
      );
    });

    test('wraps a database error of a parameterized query too', () async {
      final error = PgException('duplicate key value');
      final session = PostgresSession(FailingTxSession(error));

      await expectLater(
        session.query(
          'INSERT INTO widgets (id) VALUES (@id)',
          parameters: {'id': 1},
        ),
        throwsA(
          isA<QueryExecutionException>()
              .having(
                (e) => e.sql,
                'sql',
                'INSERT INTO widgets (id) VALUES (@id)',
              )
              .having((e) => e.cause, 'cause', same(error)),
        ),
      );
    });
  });
}
