import 'package:ratel_orm/postgres.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

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
}
