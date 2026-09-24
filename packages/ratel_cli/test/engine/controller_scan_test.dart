import 'package:ratel_cli/src/engine/model/parameter_source.dart';
import 'package:ratel_cli/src/engine/model/scanned_controller.dart';
import 'package:test/test.dart';

import '../support/engine_harness.dart';

void main() {
  late List<ScannedController> controllers;

  setUpAll(() async {
    final result = await EngineHarness.generate(
      'kitchen_sink',
      packageName: 'kitchen_sink_app',
    );
    expect(result.hasErrors, isFalse, reason: '${result.diagnostics}');
    controllers = result.app.controllers;
  });

  ScannedController named(String name) =>
      controllers.singleWhere((controller) => controller.element.name == name);

  test('finds controllers in lib and next to the entrypoint', () {
    expect(
      controllers.map((controller) => controller.element.name),
      unorderedEquals(
        ['GreetingController', 'ItemsController', 'HealthController'],
      ),
    );
  });

  test('joins the prefix and resolves protection per route', () {
    final routes = {
      for (final route in named('ItemsController').routes)
        '${route.verb} ${route.path}': route,
    };
    expect(routes.keys, containsAll(['GET /items/:id', 'POST /items/upload']));
    expect(routes['GET /items/:id']!.isProtected, isFalse);
    expect(routes['GET /items/admin/secret']!.isProtected, isTrue);
    expect(routes['GET /items/admin/secret']!.roles, ['admin']);
  });

  test('resolves protection per socket the way it does per route', () {
    final sockets = {
      for (final socket in named('ItemsController').sockets)
        socket.path: socket,
    };
    expect(
      sockets.keys,
      unorderedEquals(['/items/ws', '/items/admin/ws', '/items/member/ws']),
    );
    expect(sockets['/items/ws']!.isProtected, isFalse);
    expect(sockets['/items/ws']!.roles, isEmpty);
    expect(sockets['/items/admin/ws']!.isProtected, isTrue);
    expect(sockets['/items/admin/ws']!.roles, ['admin']);
    expect(sockets['/items/member/ws']!.isProtected, isTrue);
    expect(sockets['/items/member/ws']!.roles, isEmpty);
  });

  test('classifies every parameter', () {
    final search = named('ItemsController')
        .routes
        .singleWhere((route) => route.methodName == 'search');
    expect(search.parameters.map((parameter) => parameter.source), [
      ParameterSource.header,
      ParameterSource.cookie,
      ParameterSource.context,
    ]);
    final upload = named('ItemsController')
        .routes
        .singleWhere((route) => route.methodName == 'upload');
    expect(upload.parameters.map((parameter) => parameter.source), [
      ParameterSource.multipart,
      ParameterSource.body,
    ]);
    final socket = named('ItemsController')
        .sockets
        .singleWhere((socket) => socket.methodName == 'chat');
    expect(socket.path, '/items/ws');
    expect(socket.parameters.map((parameter) => parameter.source), [
      ParameterSource.webSocket,
      ParameterSource.context,
    ]);
  });

  test('knows which controllers it can construct itself', () {
    expect(named('ItemsController').isConstructible, isTrue);
    expect(named('GreetingController').isConstructible, isFalse);
  });
}
