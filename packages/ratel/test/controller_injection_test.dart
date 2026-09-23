import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'controller_injection_test.ratel.dart';

class Greeter {
  Greeter(this.greeting);
  final String greeting;
}

/// Takes its dependency through the constructor, so it has no no-argument
/// constructor and generated code cannot build it on its own.
@Controller('/di')
class InjectedController extends RatelHandler {
  InjectedController(this.greeter);
  final Greeter greeter;

  @Get('/hello')
  Future<Response> hello() async =>
      Response.json(data: {'greeting': greeter.greeting});
}

/// Buildable without help, so generated code registers its default.
@Controller('/plain')
class PlainController extends RatelHandler {
  @Get('/hello')
  Future<Response> hello() async =>
      Response.json(data: {'greeting': 'default'});
}

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Injector().put<Greeter>(() => Greeter('injected'));
    RatelControllers.register<InjectedController>(
      () => InjectedController(Injector().get<Greeter>()),
    );
  }
}

void main() {
  // RatelServer runs its bindings from the constructor, so it has to be built
  // after the registries are reset — otherwise the reset wipes what the
  // bindings registered.
  late final RatelServer server;
  final client = HttpClient();
  late int port;

  Future<String> get(String path) async {
    final req =
        await client.openUrl('GET', Uri.parse('http://127.0.0.1:$port$path'));
    final res = await req.close();
    return res.transform(utf8.decoder).join();
  }

  setUpAll(() async {
    RatelHandler.reset();
    RatelControllers.reset();
    RatelJson.reset();
    $registerRatel();
    server = RatelServer(port: 0, bindings: AppBindings());
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
  });

  test('serves a controller built from registered dependencies', () async {
    expect(await get('/di/hello'), '{"greeting":"injected"}');
  });

  test('still serves a controller with a no-argument constructor', () async {
    expect(await get('/plain/hello'), '{"greeting":"default"}');
  });

  test('an override replaces the generated default', () {
    RatelControllers.registerDefault<PlainController>(PlainController.new);
    RatelControllers.register<PlainController>(PlainController.new);
    expect(RatelControllers.create<PlainController>(), isA<PlainController>());
  });

  test('creating an unregistered controller explains what to do', () {
    RatelControllers.reset();
    expect(
      () => RatelControllers.create<InjectedController>(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('InjectedController'),
            contains('RatelControllers.register'),
          ),
        ),
      ),
    );
  });
}
