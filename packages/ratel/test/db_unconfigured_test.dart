import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  test('Db.query throws when no driver is configured', () {
    expect(
      () => const Db().query('SELECT 1'),
      throwsA(isA<DatabaseNotConfiguredException>()),
    );
  });
}
