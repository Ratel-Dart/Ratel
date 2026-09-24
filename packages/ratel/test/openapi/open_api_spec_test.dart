import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/new_user_codec.dart';
import '../support/fixtures/definitions/open_api_doc_controller_definition.dart';

void main() {
  late Map<String, dynamic> spec;

  Map<String, dynamic> operation(
    Map<String, dynamic> spec,
    String path, [
    String verb = 'get',
  ]) {
    final paths = spec['paths'] as Map<String, dynamic>;
    return (paths[path] as Map<String, dynamic>)[verb] as Map<String, dynamic>;
  }

  setUpAll(() {
    final registry = RatelRegistry.fromManifest(
      const RatelManifest(
        controllers: [OpenApiDocControllerDefinition.value],
        jsonCodecs: [NewUserCodec.definition],
      ),
    );
    spec = OpenApiSpec.build(registry.routes, title: 'Users', version: '2.0');
  });

  test('describes itself with the given title and version', () {
    expect(spec['openapi'], '3.0.0');
    expect(spec['info'], {'title': 'Users', 'version': '2.0'});
  });

  test('turns :name segments into OpenAPI path templates', () {
    expect(
      (spec['paths'] as Map<String, dynamic>).keys,
      containsAll(['/api/users/{id}', '/api/users']),
    );
  });

  test('describes every parameter with its location and type', () {
    final parameters = operation(spec, '/api/users/{id}')['parameters'] as List;

    expect(parameters, [
      {
        'name': 'id',
        'in': 'path',
        'required': true,
        'schema': {'type': 'integer'},
      },
      {
        'name': 'format',
        'in': 'query',
        'required': false,
        'schema': {'type': 'string'},
      },
      {
        'name': 'X-Trace',
        'in': 'header',
        'required': false,
        'schema': {'type': 'string'},
      },
    ]);
  });

  test('gives a body route a JSON request body named after its class', () {
    final post = operation(spec, '/api/users', 'post');
    final content = post['requestBody'] as Map<String, dynamic>;
    final schema = ((content['content'] as Map)['application/json'] as Map)
        as Map<String, dynamic>;

    expect(schema['schema'], {'type': 'object', 'title': 'NewUser'});
  });

  test('carries the required roles on a protected operation', () {
    expect(operation(spec, '/api/users', 'post')['security'], [
      {
        'bearerAuth': ['admin'],
      },
    ]);
  });

  test('leaves a public route unsecured', () {
    expect(operation(spec, '/api/users/{id}')['security'], isNull);
  });

  test('declares the bearerAuth security scheme', () {
    final schemes =
        (spec['components'] as Map)['securitySchemes'] as Map<String, dynamic>;
    expect(schemes['bearerAuth'], {
      'type': 'http',
      'scheme': 'bearer',
      'bearerFormat': 'JWT',
    });
  });
}
