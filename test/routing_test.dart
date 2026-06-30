import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

@Protected()
class _GreetController extends RatelHandler {
  @Get('/ping')
  @Public()
  Future<Response> ping() async =>
      Response.json(statusCode: 200, data: {'pong': true});

  @Post('/greet')
  Future<Response> greet() async =>
      Response.json(statusCode: 201, data: <String, dynamic>{});
}

void main() {
  group('RatelHandler route registration', () {
    setUpAll(_GreetController.new);

    test('registers a GET route from a @Get annotation', () {
      final route = RatelHandler.routes
          .firstWhere((r) => r.path == '/ping' && r.method == 'GET');
      expect(route, isNotNull);
    });

    test('registers a POST route from a @Post annotation', () {
      final route = RatelHandler.routes
          .firstWhere((r) => r.path == '/greet' && r.method == 'POST');
      expect(route, isNotNull);
    });

    test('@Public opts a method out of a @Protected controller', () {
      final ping = RatelHandler.routes
          .firstWhere((r) => r.path == '/ping' && r.method == 'GET');
      expect(ping.isProtected, isFalse);
    });

    test('methods inherit @Protected from the controller', () {
      final greet = RatelHandler.routes
          .firstWhere((r) => r.path == '/greet' && r.method == 'POST');
      expect(greet.isProtected, isTrue);
    });
  });
}
