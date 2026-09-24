import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/cluster_probe.dart';
import '../support/fixtures/definitions/binding_controller_definition.dart';

void main() {
  test('every isolate of a cluster gets the installed manifest', () async {
    RatelRuntime.install(
      const RatelManifest(controllers: [BindingControllerDefinition.value]),
    );
    final dir = await Directory.systemTemp.createTemp('ratel_cluster');
    addTearDown(() => dir.delete(recursive: true));

    await RatelCluster.run(ClusterProbe.record, isolates: 3, args: [dir.path]);

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (dir.listSync().length < 3 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final counts = [
      for (final file in dir.listSync().whereType<File>())
        file.readAsStringSync(),
    ];
    expect(counts, ['5', '5', '5']);
  });
}
