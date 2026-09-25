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

  group('Router.match specificity', () {
    test('prefers a static segment over a parameter declared first', () {
      final router = Router([
        route('GET', '/users/:name'),
        route('GET', '/users/me'),
      ]);
      final match = router.match('GET', '/users/me');
      expect(match!.route.path, '/users/me');
      expect(match.params, isEmpty);
    });

    test('prefers a static segment over a parameter declared after', () {
      final router = Router([
        route('GET', '/users/me'),
        route('GET', '/users/:name'),
      ]);
      expect(router.match('GET', '/users/me')!.route.path, '/users/me');
    });

    test('still routes other values to the parameter', () {
      final router = Router([
        route('GET', '/users/me'),
        route('GET', '/users/:name'),
      ]);
      final match = router.match('GET', '/users/ada');
      expect(match!.route.path, '/users/:name');
      expect(match.params, {'name': 'ada'});
    });

    test('compares nested routes at the first differing segment', () {
      for (final routes in [
        [route('GET', '/a/:x/c'), route('GET', '/a/b/:y')],
        [route('GET', '/a/b/:y'), route('GET', '/a/:x/c')],
      ]) {
        final router = Router(routes);
        final both = router.match('GET', '/a/b/c');
        expect(both!.route.path, '/a/b/:y');
        expect(both.params, {'y': 'c'});
        final first = router.match('GET', '/a/z/c');
        expect(first!.route.path, '/a/:x/c');
        expect(first.params, {'x': 'z'});
      }
    });

    test('keeps declaration order for equally specific routes', () {
      final router = Router([
        route('GET', '/files/:first'),
        route('GET', '/files/:second'),
      ]);
      expect(router.match('GET', '/files/x')!.params, {'first': 'x'});
    });

    test('only weighs routes for the requested method', () {
      final router = Router([
        route('GET', '/users/:name'),
        route('POST', '/users/me'),
      ]);
      final match = router.match('GET', '/users/me');
      expect(match!.route.path, '/users/:name');
      expect(match.params, {'name': 'me'});
    });
  });

  group('Router.match decoding', () {
    final router = Router([
      route('GET', '/users/:name'),
      route('GET', '/tags/c++'),
    ]);

    test('percent-decodes unicode in a parameter', () {
      expect(router.match('GET', '/users/Jo%C3%A3o')!.params, {'name': 'João'});
    });

    test('percent-decodes spaces in a parameter', () {
      expect(
        router.match('GET', '/users/Ada%20Lovelace')!.params,
        {'name': 'Ada Lovelace'},
      );
    });

    test('decodes an encoded slash inside a single segment', () {
      expect(router.match('GET', '/users/a%2Fb')!.params, {'name': 'a/b'});
    });

    test('decodes a segment before comparing it to a static one', () {
      expect(router.match('GET', '/tags/c%2B%2B')!.route.path, '/tags/c++');
    });

    test('decodes escapes written in a static route segment', () {
      final router = Router([route('GET', '/caf%C3%A9/a%2Fb')]);
      expect(
        router.match('GET', '/caf%C3%A9/a%2Fb')!.route.path,
        '/caf%C3%A9/a%2Fb',
      );
      expect(router.match('GET', '/caf%c3%a9/a%2fb'), isNotNull);
    });

    test('matches a static route segment written decoded', () {
      final router = Router([route('GET', '/café/a b')]);
      expect(router.match('GET', '/caf%C3%A9/a%20b')!.route.path, '/café/a b');
    });

    test('keeps a static route segment whose escape is malformed', () {
      final router = Router([route('GET', '/sale/50%off')]);
      expect(router.match('GET', '/sale/50%25off')!.route.path, '/sale/50%off');
    });

    test('rejects a malformed escape with a bad request', () {
      expect(
        () => router.match('GET', '/users/%E0%A4%A'),
        throwsA(isA<BadRequestException>()),
      );
      expect(
        () => router.match('GET', '/users/%E0%A4%25A'),
        throwsA(isA<BadRequestException>()),
      );
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

    test('lists every method whose pattern matches the path', () {
      final router = Router([
        route('GET', '/users/:name'),
        route('DELETE', '/users/me'),
      ]);
      expect(router.allowedMethods('/users/me'), {'GET', 'DELETE'});
      expect(router.allowedMethods('/users/ada'), {'GET'});
    });
  });
}
