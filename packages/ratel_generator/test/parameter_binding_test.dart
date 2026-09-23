import 'package:test/test.dart';

import 'support/generator_harness.dart';

const _imports = '''
import 'package:ratel/annotations/annotations.dart';
import 'package:ratel/http/handler.dart';
''';

void main() {
  test('coerces a @PathParam from the matched path segment', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class PathController extends RatelHandler {
  @Get('/users/:id')
  Future<String> byId(@PathParam('id') int id) async => '';
}
''',
    });

    expect(
      output,
      stringContainsInOrder([
        '.byId(',
        '_r.coerceParam(',
        "'id'",
        "ctx.pathParams['id']",
        'int) as int)',
      ]),
    );
  });

  test('coerces a @Param from the query string by parameter name', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class QueryController extends RatelHandler {
  @Get('/search')
  Future<String> search(@Param() String? term) async => '';
}
''',
    });

    expect(
      output,
      stringContainsInOrder([
        'controller().search(',
        '_r.coerceParam(',
        "'term'",
        "ctx.request.uri.queryParameters['term']",
        'String) as String?)',
      ]),
    );
  });

  test('coerces a @Header from the request headers', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class HeaderController extends RatelHandler {
  @Get('/me')
  Future<String> me(@Header('X-User') String? user) async => '';
}
''',
    });

    expect(
      output,
      stringContainsInOrder([
        'controller().me(',
        '_r.coerceParam(',
        "'X-User'",
        "ctx.request.headers.value('X-User')",
        'String) as String?)',
      ]),
    );
  });

  test('coerces a @CookieParam from the request cookies', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class CookieController extends RatelHandler {
  @Get('/session')
  Future<String> session(@CookieParam('sid') int? sid) async => '';
}
''',
    });

    expect(
      output,
      stringContainsInOrder([
        'controller().session(',
        '_r.coerceParam(',
        "'sid'",
        "_r.cookieValue(ctx.request.cookies, 'sid')",
        'int) as int?)',
      ]),
    );
  });

  test('passes null for an unannotated parameter', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class LooseController extends RatelHandler {
  @Get('/loose')
  Future<String> loose([String? ignored]) async => '';
}
''',
    });

    expect(output, contains('return await controller().loose(null);'));
  });

  test('binds every parameter of a handler in order', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class MixedController extends RatelHandler {
  @Get('/reports/:id')
  Future<String> report(
    @PathParam('id') int id,
    @Param() String? format,
    @Header('X-Trace') String? trace,
  ) async => '';
}
''',
    });

    final call = RegExp(r'controller\(\)\.report\((.*)\);', dotAll: true)
        .firstMatch(output)!
        .group(1)!;
    expect(call.indexOf("'id'"), lessThan(call.indexOf("'format'")));
    expect(call.indexOf("'format'"), lessThan(call.indexOf("'X-Trace'")));
  });
}
