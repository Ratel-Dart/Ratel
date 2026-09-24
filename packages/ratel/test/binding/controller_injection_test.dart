import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/bindings/injected_greeting_bindings.dart';
import '../support/fixtures/controllers/default_greeting_controller.dart';
import '../support/fixtures/definitions/default_greeting_controller_definition.dart';
import '../support/fixtures/definitions/injected_greeting_controller_definition.dart';
import '../support/http_probe.dart';

void main() {
  late RatelServer server;
  late HttpProbe probe;

  Future<String> get(HttpProbe target, String path) async {
    final (_, body) = await target.send('GET', path);
    return body;
  }

  Future<RatelServer> serve(
    RatelManifest manifest, {
    ErrorHandler? onError,
  }) async {
    final started = RatelServer(
      port: 0,
      registry: RatelRegistry.fromManifest(manifest),
      onError: onError,
    );
    await started.startServer();
    addTearDown(() => started.stop(force: true));
    return started;
  }

  void useInjector(Injector injector) {
    final previous = Injector.ambient;
    Injector.ambient = injector;
    addTearDown(() => Injector.ambient = previous);
  }

  setUpAll(() async {
    Injector.ambient = Injector.scoped();
    server = RatelServer(
      port: 0,
      bindings: InjectedGreetingBindings(),
      registry: RatelRegistry.fromManifest(
        const RatelManifest(
          controllers: [
            InjectedGreetingControllerDefinition.value,
            DefaultGreetingControllerDefinition.value,
          ],
        ),
      ),
    );
    await server.startServer();
    probe = HttpProbe(server.boundPort!);
  });

  tearDownAll(() => server.stop(force: true));

  test('serves a controller built from registered dependencies', () async {
    expect(await get(probe, '/di/hello'), '{"greeting":"injected"}');
  });

  test('still serves a controller with a no-argument constructor', () async {
    expect(await get(probe, '/plain/hello'), '{"greeting":"default"}');
  });

  test('an injector registration replaces the default constructor', () async {
    var overrides = 0;
    useInjector(Injector.scoped()
      ..put<DefaultGreetingController>(() {
        overrides++;
        return DefaultGreetingController();
      }));
    final overridden = await serve(
      const RatelManifest(
        controllers: [DefaultGreetingControllerDefinition.value],
      ),
    );
    expect(
      await get(HttpProbe(overridden.boundPort!), '/plain/hello'),
      '{"greeting":"default"}',
    );
    expect(overrides, 1);
  });

  test('creating an unregistered controller explains what to do', () async {
    useInjector(Injector.scoped());
    Object? failure;
    final unregistered = await serve(
      const RatelManifest(
        controllers: [InjectedGreetingControllerDefinition.value],
      ),
      onError: (error, stackTrace, ctx) {
        failure = error;
        return Response(statusCode: 500);
      },
    );
    await get(HttpProbe(unregistered.boundPort!), '/di/hello');
    expect(
      failure,
      isA<StateError>().having(
        (e) => e.message,
        'message',
        allOf(
          contains('InjectedGreetingController'),
          contains('Injector().put<InjectedGreetingController>'),
        ),
      ),
    );
  });
}
