import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

@Json()
class _NewUser {
  String name = '';
}

@Controller('/api')
class _DocController extends RatelHandler {
  @Get('/users/:id')
  Future<Response> getUser(@PathParam('id') int id) async =>
      Response.json(statusCode: 200, data: {});

  @Protected()
  @Post('/users')
  Future<Response> create(@Body() _NewUser body) async =>
      Response.json(statusCode: 201, data: {});
}

void main() {
  setUpAll(_DocController.new);

  test('generates paths with OpenAPI-style path parameters', () {
    final spec =
        openApiSpec(RatelHandler.routes, title: 'Test', version: '1.0');
    final paths = spec['paths'] as Map<String, dynamic>;
    expect(paths.containsKey('/api/users/{id}'), isTrue);

    final get = (paths['/api/users/{id}'] as Map)['get'] as Map;
    final params = get['parameters'] as List;
    expect(
      params.any((p) => (p as Map)['name'] == 'id' && p['in'] == 'path'),
      isTrue,
    );
  });

  test('marks protected operations with security and bodies', () {
    final spec = openApiSpec(RatelHandler.routes);
    final post = ((spec['paths'] as Map)['/api/users'] as Map)['post'] as Map;
    expect(post['security'], isNotNull);
    expect(post['requestBody'], isNotNull);
  });

  test('declares the bearerAuth security scheme', () {
    final spec = openApiSpec(RatelHandler.routes);
    final schemes =
        (spec['components'] as Map)['securitySchemes'] as Map<String, dynamic>;
    expect(schemes.containsKey('bearerAuth'), isTrue);
  });
}
