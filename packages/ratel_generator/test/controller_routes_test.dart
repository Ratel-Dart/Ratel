import 'package:test/test.dart';

import 'support/generator_harness.dart';

const _imports = '''
import 'package:ratel/annotations/annotations.dart';
import 'package:ratel/http/handler.dart';
''';

void main() {
  test('emits a route table for every verb', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class VerbController extends RatelHandler {
  @Get('/get')
  Future<String> read() async => 'get';

  @Post('/post')
  Future<String> create() async => 'post';

  @Put('/put')
  Future<String> replace() async => 'put';

  @Delete('/delete')
  Future<String> remove() async => 'delete';

  @Patch('/patch')
  Future<String> amend() async => 'patch';

  @Head('/head')
  Future<String> peek() async => 'head';

  @Options('/options')
  Future<String> describe() async => 'options';
}
''',
    });

    for (final verb in const [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'HEAD',
      'OPTIONS',
    ]) {
      expect(output, contains("method: '$verb',"));
    }
    expect(output, contains("path: '/get',"));
    expect(output, contains("path: '/options',"));
  });

  test('joins the @Controller prefix with each route path', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

@Controller('api/v1/')
class UserController extends RatelHandler {
  @Get('/users')
  Future<String> list() async => '';

  @Get('users/:id')
  Future<String> byId() async => '';

  @Get('/')
  Future<String> root() async => '';
}
''',
    });

    expect(output, contains("path: '/api/v1/users',"));
    expect(output, contains("path: '/api/v1/users/:id',"));
    expect(output, contains("path: '/api/v1',"));
  });

  test('marks routes protected from the class and honours @Public', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

@Protected(roles: ['admin', 'staff'])
class AdminController extends RatelHandler {
  @Get('/secret')
  Future<String> secret() async => '';

  @Public()
  @Get('/open')
  Future<String> open() async => '';

  @Protected()
  @Get('/any')
  Future<String> any() async => '';
}
''',
    });

    expect(
      output,
      contains('''
    path: '/secret',
    method: 'GET',
    isProtected: true,
    requiredRoles: const ['admin', 'staff'],'''),
    );
    expect(
      output,
      contains('''
    path: '/open',
    method: 'GET',
    isProtected: false,
    requiredRoles: const [],'''),
    );
    expect(
      output,
      contains('''
    path: '/any',
    method: 'GET',
    isProtected: true,
    requiredRoles: const [],'''),
    );
  });

  test('reads the request body only for handlers with a @Body parameter',
      () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

@Json()
class Invoice {
  int amount = 0;
}

class InvoiceController extends RatelHandler {
  @Post('/invoices')
  Future<String> create(@Body() Invoice invoice) async => '';

  @Get('/invoices')
  Future<String> list() async => '';
}
''',
    });

    expect(output, contains('_r.readBodyLimited('));
    expect(
      output,
      contains(
          'return await controller().create(\$InvoiceFromJson(jsonBody));'),
    );
    expect(output, contains('return await controller().list();'));
    expect('_r.readBodyLimited('.allMatches(output).length, 1);
  });

  test('skips static methods and unannotated methods', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class MixedController extends RatelHandler {
  @Get('/live')
  Future<String> live() async => '';

  static Future<String> helper() async => '';

  Future<String> notARoute() async => '';
}
''',
    });

    expect(output, contains("path: '/live',"));
    expect(output, isNot(contains('helper')));
    expect(output, isNot(contains('notARoute')));
  });

  test('ignores abstract controllers', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

abstract class BaseController extends RatelHandler {
  @Get('/base')
  Future<String> base() async => '';
}

class RealController extends RatelHandler {
  @Get('/real')
  Future<String> real() async => '';
}
''',
    });

    expect(output, contains('\$RealControllerRoutes'));
    expect(output, isNot(contains('\$BaseControllerRoutes')));
  });
}
