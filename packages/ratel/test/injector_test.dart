import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _Service {
  int calls = 0;
}

void main() {
  group('Injector', () {
    test('returns the same singleton instance on repeated get', () {
      final injector = Injector();
      injector.put<_Service>(_Service.new);

      final a = injector.get<_Service>();
      final b = injector.get<_Service>();

      expect(identical(a, b), isTrue);
    });

    test('throws when the requested type is not registered', () {
      // Injector is a process-wide singleton, so use a type this suite never
      // registers.
      expect(() => Injector().get<DateTime>(), throwsA(isA<Exception>()));
    });
  });
}
