import 'package:ratel/ratel.dart';
import 'package:ratel/src/routing/route_path.dart';
import 'package:ratel/src/routing/router.dart';
import 'package:test/test.dart';

void main() {
  Route route(String method, String path) =>
      Route(method: method, path: path, handler: (_) async => null);

  group('RoutePath.split', () {
    test('splits a path and trims slashes', () {
      expect(RoutePath.split('/users/42'), ['users', '42']);
      expect(RoutePath.split('/users/'), ['users']);
      expect(RoutePath.split('/'), isEmpty);
    });
  });

  group('Router.match', () {
    final router = Router([
      route('GET', '/users'),
      route('GET', '/users/:id'),
      route('POST', '/users'),
    ]);

    test('matches a static route with no params', () {
      final match = router.match('GET', '/users');
      expect(match, isNotNull);
      expect(match!.params, isEmpty);
    });

    test('matches and captures a path parameter', () {
      final match = router.match('GET', '/users/42');
      expect(match, isNotNull);
      expect(match!.params['id'], '42');
    });

    test('returns null when the method does not match', () {
      expect(router.match('DELETE', '/users'), isNull);
    });

    test('returns null when nothing matches', () {
      expect(router.match('GET', '/nope'), isNull);
    });
  });

  group('Router.allowedMethods', () {
    final router = Router([
      route('GET', '/users'),
      route('POST', '/users'),
      route('GET', '/users/:id'),
    ]);

    test('lists methods for a static path', () {
      expect(router.allowedMethods('/users'), {'GET', 'POST'});
    });

    test('lists methods for a parameterized path', () {
      expect(router.allowedMethods('/users/42'), {'GET'});
    });

    test('is empty for an unknown path', () {
      expect(router.allowedMethods('/nope'), isEmpty);
    });
  });
}
