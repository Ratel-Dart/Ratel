import 'package:postgres/postgres.dart' show ServerException;
import 'package:ratel_orm/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

import '../support/fake_postgres_server.dart';

void main() {
  group('PostgresDriver', () {
    test('is a RatelDriver', () {
      final driver = PostgresDriver(
        host: 'localhost',
        databaseName: 'app',
        username: 'user',
        password: 'secret',
      );
      expect(driver, isA<RatelDriver>());
      expect(driver.dialect, isA<PostgresDialect>());
      expect(driver.port, 5432);
      expect(driver.sslMode, SslMode.require);
    });

    test('maxConnections defaults to 10 and is configurable', () {
      PostgresDriver make({int? max}) => PostgresDriver(
            host: 'h',
            databaseName: 'd',
            username: 'u',
            password: 'p',
            maxConnections: max ?? 10,
          );
      expect(make().maxConnections, 10);
      expect(make(max: 5).maxConnections, 5);
    });

    test('open builds the pool once and close drains it (no connection)',
        () async {
      final driver = PostgresDriver(
        host: 'localhost',
        databaseName: 'app',
        username: 'user',
        password: 'secret',
        sslMode: SslMode.disable,
      );
      await driver.open();
      await driver.open();
      await driver.close();
    });
  });

  group('PostgresDriver.transaction', () {
    Future<(FakePostgresServer, PostgresDriver)> connect({
      Set<String> failing = const {},
    }) async {
      final server = await FakePostgresServer.start(failing: failing);
      final driver = PostgresDriver(
        host: '127.0.0.1',
        port: server.port,
        databaseName: 'app',
        username: 'user',
        password: 'secret',
        sslMode: SslMode.disable,
      );
      addTearDown(() async {
        await driver.close();
        await server.close();
      });
      return (server, driver);
    }

    test('lets a user error propagate unchanged after the rollback', () async {
      final (server, driver) = await connect();
      final error = StateError('boom');

      await expectLater(
        driver.transaction<void>((session) async => throw error),
        throwsA(same(error)),
      );
      expect(server.statements, ['BEGIN', 'ROLLBACK']);
    });

    test('wraps a failing BEGIN in a QueryExecutionException', () async {
      final (_, driver) = await connect(failing: {'BEGIN'});

      await expectLater(
        driver.transaction((session) async => 1),
        throwsA(
          isA<QueryExecutionException>()
              .having((e) => e.sql, 'sql', 'BEGIN')
              .having((e) => e.cause, 'cause', isA<ServerException>()),
        ),
      );
    });

    test('wraps a failing COMMIT in a QueryExecutionException', () async {
      final (server, driver) = await connect(failing: {'COMMIT'});

      await expectLater(
        driver.transaction((session) async => 1),
        throwsA(
          isA<QueryExecutionException>()
              .having((e) => e.sql, 'sql', 'COMMIT')
              .having((e) => e.cause, 'cause', isA<ServerException>()),
        ),
      );
      expect(server.statements, ['BEGIN', 'COMMIT']);
    });
  });
}
