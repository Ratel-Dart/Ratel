import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

Route _route(String method, String path) =>
    Route(method: method, path: path, handler: ([_]) async => null);

void main() {
  group('splitPath', () {
    test('splits a path and trims slashes', () {
      expect(splitPath('/users/42'), ['users', '42']);
      expect(splitPath('/users/'), ['users']);
      expect(splitPath('/'), isEmpty);
    });
  });

  group('Router.match', () {
    final router = Router([
      _route('GET', '/users'),
      _route('GET', '/users/:id'),
      _route('POST', '/users'),
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
      _route('GET', '/users'),
      _route('POST', '/users'),
      _route('GET', '/users/:id'),
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
