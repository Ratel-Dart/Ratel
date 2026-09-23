import 'package:test/test.dart';

import 'support/generator_harness.dart';

const _imports = '''
import 'package:ratel/annotations/annotations.dart';
import 'package:ratel/http/handler.dart';
''';

void main() {
  test('describes each bound parameter on the route', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class ReportController extends RatelHandler {
  @Get('/reports/:id')
  Future<String> report(
    @PathParam('id') int id,
    @Param() String? format,
    @Header('X-Trace') String trace,
    @CookieParam('session') String? session,
  ) async => '';
}
''',
    });

    expect(
      output,
      stringContainsInOrder([
        "name: 'id'",
        'location: _r.ParameterLocation.path',
        'type: int',
        'isRequired: true',
        "name: 'format'",
        'location: _r.ParameterLocation.query',
        'isRequired: false',
        "name: 'X-Trace'",
        'location: _r.ParameterLocation.header',
        'isRequired: true',
        "name: 'session'",
        'location: _r.ParameterLocation.cookie',
        'isRequired: false',
      ]),
    );
  });

  test('names the @Body class as the route body type', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

@Json()
class Profile {
  String name = '';
}

class ProfileController extends RatelHandler {
  @Post('/profile')
  Future<String> save(@Body() Profile profile) async => '';
}
''',
    });

    expect(output, contains("bodyType: 'Profile'"));
  });

  test('leaves a route without inputs empty', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class PingController extends RatelHandler {
  @Get('/ping')
  Future<String> ping() async => '';
}
''',
    });

    expect(output, contains('parameters: const [],'));
    expect(output, contains('bodyType: null,'));
  });
}
