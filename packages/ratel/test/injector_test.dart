import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'support/fakes/fake_service.dart';

void main() {
  group('Injector', () {
    test('returns the same singleton instance on repeated get', () {
      final injector = Injector();
      injector.put<FakeService>(FakeService.new);

      final a = injector.get<FakeService>();
      final b = injector.get<FakeService>();

      expect(identical(a, b), isTrue);
    });

    test('throws when the requested type is not registered', () {
      expect(() => Injector().get<DateTime>(), throwsA(isA<Exception>()));
    });
  });
}
