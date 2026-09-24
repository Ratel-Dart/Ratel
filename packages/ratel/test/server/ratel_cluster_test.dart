import 'dart:async';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/cluster_probe.dart';
import '../support/cluster_run_recorder.dart';

void main() {
  Route pingRoute() => Route(
        path: '/ping',
        method: 'GET',
        handler: (_) async => Response.json(data: {'ok': true}),
      );

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
      registry: RatelRegistry()..register(pingRoute()),
    );
    await server.startServer();

    expect(await ping(server.boundPort!), 200);
    await server.stop(force: true);
  });

  test('two shared servers listen on one port', () async {
    final first = RatelServer(
      port: 0,
      shared: true,
      registry: RatelRegistry()..register(pingRoute()),
    );
    await first.startServer();
    final port = first.boundPort!;

    final second = RatelServer(
      port: port,
      shared: true,
      registry: RatelRegistry()..register(pingRoute()),
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
      registry: RatelRegistry()..register(pingRoute()),
    );
    await first.startServer();

    final second = RatelServer(
      port: first.boundPort!,
      registry: RatelRegistry()..register(pingRoute()),
    );
    await expectLater(second.startServer(), throwsA(isA<SocketException>()));

    await first.stop(force: true);
  });

  test('RatelCluster.run runs the entry point on every isolate', () async {
    await withTempDir((dir) async {
      await RatelCluster.run(ClusterRunRecorder.record,
          isolates: 3, args: [dir.path]);
      await ClusterRunRecorder.waitForRuns(dir, 3);
      expect(ClusterRunRecorder.runsIn(dir), 3);
    });
  });

  test('RatelCluster.run with a single isolate spawns none', () async {
    await withTempDir((dir) async {
      await RatelCluster.run(ClusterRunRecorder.record,
          isolates: 1, args: [dir.path]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(ClusterRunRecorder.runsIn(dir), 1);
    });
  });

  test('every isolate of a cluster gets the installed manifest', () async {
    RatelRuntime.install(ClusterProbe.manifest);
    final dir = await Directory.systemTemp.createTemp('ratel_cluster');
    addTearDown(() => dir.delete(recursive: true));

    await RatelCluster.run(ClusterProbe.record, isolates: 3, args: [dir.path]);

    expect(await ClusterProbe.recordsIn(dir, 3), ['5', '5', '5']);
  });

  test('every isolate of a cluster runs the isolate setup once', () async {
    RatelRuntime.install(ClusterProbe.manifest);
    final dir = await Directory.systemTemp.createTemp('ratel_cluster');
    addTearDown(() => dir.delete(recursive: true));

    await RatelCluster.run(
      ClusterProbe.recordSetups,
      isolates: 3,
      args: [dir.path],
    );

    expect(await ClusterProbe.recordsIn(dir, 3), ['1', '1', '1']);
  });
}
