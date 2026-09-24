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
}
