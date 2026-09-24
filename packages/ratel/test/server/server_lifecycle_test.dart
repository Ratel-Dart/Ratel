import 'dart:async';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  test('onStartup runs before the port is bound', () async {
    int? portSeenByStartup = -1;
    late RatelServer server;
    server = RatelServer(
      port: 0,
      registry: RatelRegistry(),
      onStartup: () async => portSeenByStartup = server.boundPort,
    );
    await server.startServer();
    addTearDown(server.stop);

    expect(portSeenByStartup, isNull);
    expect(server.boundPort, isNotNull);
  });

  test('startServer fails fast when onStartup throws', () async {
    final server = RatelServer(
      port: 0,
      registry: RatelRegistry(),
      onStartup: () async => throw StateError('cannot connect'),
    );

    await expectLater(server.startServer(), throwsA(isA<StateError>()));
    expect(server.boundPort, isNull);
  });

  test('stop runs onShutdown', () async {
    var shutDown = false;
    final server = RatelServer(
      port: 0,
      registry: RatelRegistry(),
      onShutdown: () async => shutDown = true,
    );
    await server.startServer();
    await server.stop();

    expect(shutDown, isTrue);
  });

  test('a second stop does not run onShutdown again', () async {
    var shutdowns = 0;
    final server = RatelServer(
      port: 0,
      registry: RatelRegistry(),
      onShutdown: () async => shutdowns++,
    );
    await server.startServer();
    await server.stop();
    await server.stop();

    expect(shutdowns, 1);
  });

  test('a stop issued during shutdown waits for the same shutdown', () async {
    var shutdowns = 0;
    final gate = Completer<void>();
    final server = RatelServer(
      port: 0,
      registry: RatelRegistry(),
      onShutdown: () async {
        shutdowns++;
        await gate.future;
      },
    );
    await server.startServer();
    final first = server.stop();
    var secondDone = false;
    final second = server.stop().then((_) => secondDone = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(secondDone, isFalse);
    gate.complete();
    await Future.wait([first, second]);
    expect(secondDone, isTrue);
    expect(shutdowns, 1);
  });

  test('a restarted server runs onShutdown on its next stop', () async {
    var shutdowns = 0;
    final server = RatelServer(
      port: 0,
      registry: RatelRegistry(),
      onShutdown: () async => shutdowns++,
    );
    await server.startServer();
    await server.stop();
    await server.startServer();
    await server.stop();

    expect(shutdowns, 2);
    expect(server.boundPort, isNull);
  });
}
