import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  test('an isolate without a manifest refuses to build its routes', () {
    expect(
      RatelRegistry.installed,
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('ratel dev'),
      )),
    );
  });
}
