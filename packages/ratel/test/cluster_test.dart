import 'dart:async';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

Route get _ping => Route(
      path: '/ping',
      method: 'GET',
      handler: ([ctxArg]) async => Response.json(data: {'ok': true}),
    );

/// Records one run per isolate. Each isolate writes its own file, because a
/// shared one is appended to concurrently and the writes overwrite each other.
void recordRun(List<String> args) {
  final name = '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
  File('${args.first}/$name').writeAsStringSync('.');
}

int runsIn(Directory dir) => dir.listSync().length;

Future<void> waitForRuns(Directory dir, int expected) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (runsIn(dir) >= expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('only ${runsIn(dir)} of $expected runs recorded');
}

void main() {
  final client = HttpClient();

  tearDownAll(() => client.close(force: true));

  Future<int> ping(int port) async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/ping'));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  Future<T> withTempDir<T>(Future<T> Function(Directory dir) body) async {
    final dir = await Directory.systemTemp.createTemp('ratel_cluster_');
    try {
      return await body(dir);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  test('a shared server binds and serves', () async {
    final server = RatelServer(
      port: 0,
      shared: true,
      registry: RatelRegistry()..register(_ping),
    );
    await server.startServer();

    expect(await ping(server.boundPort!), 200);
    await server.stop(force: true);
  });

  test('two shared servers listen on one port', () async {
    final first = RatelServer(
      port: 0,
      shared: true,
      registry: RatelRegistry()..register(_ping),
    );
    await first.startServer();
    final port = first.boundPort!;

    final second = RatelServer(
      port: port,
      shared: true,
      registry: RatelRegistry()..register(_ping),
    );
    await second.startServer();

    for (var i = 0; i < 8; i++) {
      expect(await ping(port), 200);
    }

    await first.stop(force: true);
    await second.stop(force: true);
  });

  test('without shared, a second server cannot take the port', () async {
    final first = RatelServer(
      port: 0,
      registry: RatelRegistry()..register(_ping),
    );
    await first.startServer();

    final second = RatelServer(
      port: first.boundPort!,
      registry: RatelRegistry()..register(_ping),
    );
    await expectLater(second.startServer(), throwsA(isA<SocketException>()));

    await first.stop(force: true);
  });

  test('runCluster runs the entry point on every isolate', () async {
    await withTempDir((dir) async {
      await runCluster(recordRun, isolates: 3, args: [dir.path]);
      await waitForRuns(dir, 3);
      expect(runsIn(dir), 3);
    });
  });

  test('runCluster with a single isolate spawns none', () async {
    await withTempDir((dir) async {
      await runCluster(recordRun, isolates: 1, args: [dir.path]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(runsIn(dir), 1);
    });
  });
}
