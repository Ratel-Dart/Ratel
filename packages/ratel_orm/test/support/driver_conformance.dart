import 'package:ratel/ratel.dart' show QueryResult, RatelDriver;
import 'package:test/test.dart';

abstract final class DriverConformance {
  static void run(
    RatelDriver Function() create, {
    String probeQuery = 'SELECT 1',
  }) {
    group('RatelDriver conformance', () {
      test('open is idempotent', () async {
        final driver = create();
        await driver.open();
        await driver.open();
        await driver.close();
      });

      test('query returns a QueryResult', () async {
        final driver = create();
        await driver.open();
        final result = await driver.query(probeQuery);
        expect(result, isA<QueryResult>());
        expect(result.rows, isA<List<Map<String, Object?>>>());
        await driver.close();
      });

      test('transaction runs the action and returns its value', () async {
        final driver = create();
        await driver.open();
        final result = await driver.transaction(
          (session) => session.query(probeQuery),
        );
        expect(result, isA<QueryResult>());
        await driver.close();
      });
    });
  }
}
