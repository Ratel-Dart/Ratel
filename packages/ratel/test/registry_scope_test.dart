import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _NamedDriver extends RatelDriver {
  _NamedDriver(this.name);

  final String name;
  String? lastSql;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    lastSql = sql;
    return QueryResult(rows: [
      {'driver': name},
    ]);
  }

  @override
  Future<T> transaction<T>(Future<T> Function(RatelSession session) action) =>
      throw UnimplementedError();
}

Route _name(String name) => Route(
      path: '/who',
      method: 'GET',
      handler: ([ctxArg]) async => Response.json(data: {'server': name}),
    );

Route get _limit => Route(
      path: '/limit',
      method: 'GET',
      handler: ([ctxArg]) async {
        final ctx = ctxArg as RequestContext;
        return Response.json(
          data: {'limit': ctx.registry.maxRequestBodyBytes},
        );
      },
    );

void main() {
  final alpha = RatelRegistry()
    ..register(_name('alpha'))
    ..register(_limit);
  final beta = RatelRegistry()
    ..register(_name('beta'))
    ..register(_limit);

  final alphaServer =
      RatelServer(port: 0, registry: alpha, maxRequestBodyBytes: 1024);
  final betaServer =
      RatelServer(port: 0, registry: beta, maxRequestBodyBytes: 16);
  final client = HttpClient();

  setUpAll(() async {
    await alphaServer.startServer();
    await betaServer.startServer();
  });

  tearDownAll(() async {
    client.close(force: true);
    await alphaServer.stop(force: true);
    await betaServer.stop(force: true);
  });

  Future<HttpClientResponse> send(
    RatelServer server,
    String method,
    String path, {
    String? body,
  }) async {
    final req = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.boundPort}$path'),
    );
    if (body != null) req.write(body);
    return req.close();
  }

  test('each server serves the routes of its own registry', () async {
    final fromAlpha = await send(alphaServer, 'GET', '/who');
    final fromBeta = await send(betaServer, 'GET', '/who');

    expect(jsonDecode(await fromAlpha.transform(utf8.decoder).join()),
        {'server': 'alpha'});
    expect(jsonDecode(await fromBeta.transform(utf8.decoder).join()),
        {'server': 'beta'});
  });

  test('each handler reads the body limit of the server it ran on', () async {
    final fromAlpha = await send(alphaServer, 'GET', '/limit');
    final fromBeta = await send(betaServer, 'GET', '/limit');

    expect(jsonDecode(await fromAlpha.transform(utf8.decoder).join()),
        {'limit': 1024});
    expect(jsonDecode(await fromBeta.transform(utf8.decoder).join()),
        {'limit': 16});
  });

  test('the ambient registry is untouched by a scoped one', () {
    final scoped = RatelRegistry();
    final routes = RatelRegistry.runScoped(scoped, () {
      RatelHandler.register(_name('scoped'));
      return RatelHandler.routes.length;
    });

    expect(routes, 1);
    expect(scoped.routes, hasLength(1));
    expect(RatelRegistry.current, isNot(same(scoped)));
    expect(RatelHandler.routes, isEmpty);
  });

  test('server.db runs on the server driver, not the configured one', () async {
    final own = _NamedDriver('own');
    final ambient = _NamedDriver('ambient');
    Db.configure(ambient);

    final server = RatelServer(port: 0, database: own);
    final result = await server.db.query('SELECT 1');

    expect(result.rows.single['driver'], 'own');
    expect(own.lastSql, 'SELECT 1');
    expect(ambient.lastSql, isNull);
  });

  test('an isolated injector keeps its registrations to itself', () {
    final scoped = Injector.scoped()..put<Duration>(() => Duration.zero);

    expect(scoped.get<Duration>(), Duration.zero);
    expect(() => Injector().get<Duration>(), throwsA(isA<Exception>()));
  });
}
