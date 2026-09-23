import 'package:ratel_generator/src/route_path.dart';
import 'package:test/test.dart';

void main() {
  test('returns the path unchanged when there is no prefix', () {
    expect(joinRoutePath('', '/users'), '/users');
    expect(joinRoutePath('', ''), '');
  });

  test('adds a leading slash to a prefix that lacks one', () {
    expect(joinRoutePath('api', '/users'), '/api/users');
  });

  test('drops a trailing slash from the prefix', () {
    expect(joinRoutePath('/api/', '/users'), '/api/users');
  });

  test('adds a separator when the path lacks a leading slash', () {
    expect(joinRoutePath('/api', 'users'), '/api/users');
  });

  test('drops the trailing slash of the joined path', () {
    expect(joinRoutePath('/api', '/'), '/api');
    expect(joinRoutePath('/api', ''), '/api');
  });

  test('keeps a root path as a single slash', () {
    expect(joinRoutePath('/', '/'), '/');
  });
}
