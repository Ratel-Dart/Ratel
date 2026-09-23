import 'package:test/test.dart';

import 'support/generator_harness.dart';

const _imports = '''
import 'package:ratel/annotations/annotations.dart';
import 'package:ratel/http/handler.dart';
''';

void main() {
  test('registers a default factory for a no-argument constructor', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class PingController extends RatelHandler {
  @Get('/ping')
  Future<String> ping() async => 'pong';
}
''',
    });

    expect(
      output,
      contains(
        '_r.RatelControllers.registerDefault<PingController>'
        '(PingController.new);',
      ),
    );
    expect(
      output,
      contains(
        '\$PingControllerRoutes(() => '
        '_r.RatelControllers.create<PingController>());',
      ),
    );
  });

  test('registers a default factory when every parameter is optional',
      () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class OptionalController extends RatelHandler {
  OptionalController({this.clock});

  final Object? clock;

  @Get('/optional')
  Future<String> ping() async => '';
}
''',
    });

    expect(
      output,
      contains('_r.RatelControllers.registerDefault<OptionalController>'),
    );
  });

  test('omits the default factory when a dependency is required', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class InjectedController extends RatelHandler {
  InjectedController(this.repository);

  final Object repository;

  @Get('/injected')
  Future<String> ping() async => '';
}
''',
    });

    expect(output, isNot(contains('registerDefault')));
    expect(
      output,
      stringContainsInOrder([
        '\$InjectedControllerRoutes(',
        '() => _r.RatelControllers.create<InjectedController>());',
      ]),
    );
  });

  test('omits the default factory when only named constructors exist',
      () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class NamedController extends RatelHandler {
  NamedController.create();

  @Get('/named')
  Future<String> ping() async => '';
}
''',
    });

    expect(output, isNot(contains('registerDefault')));
    expect(output, contains('\$NamedControllerRoutes(() => '));
  });

  test('accepts an unnamed factory constructor as the default', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class FactoryController extends RatelHandler {
  FactoryController._();

  factory FactoryController() => FactoryController._();

  @Get('/factory')
  Future<String> ping() async => '';
}
''',
    });

    expect(
      output,
      contains('_r.RatelControllers.registerDefault<FactoryController>'),
    );
  });

  test('rejects a private controller', () async {
    final errors = await generateErrors('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class _HiddenController extends RatelHandler {
  @Get('/hidden')
  Future<String> ping() async => '';
}
''',
    });

    expect(errors.join('\n'), contains('A controller must be public'));
  });
}
