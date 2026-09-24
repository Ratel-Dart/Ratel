import 'dart:io';
import 'dart:isolate';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';

import 'fixtures/definitions/binding_controller_definition.dart';

abstract final class ClusterProbe {
  static const RatelManifest manifest = RatelManifest(
    controllers: [BindingControllerDefinition.value],
    isolateSetup: [_countSetup],
  );

  static int _setups = 0;

  static void _countSetup() {
    _setups++;
  }

  static void record(List<String> args) =>
      _write(args, '${RatelRegistry.installed().routes.length}');

  static void recordSetups(List<String> args) => _write(args, '$_setups');

  static Future<List<String>> recordsIn(Directory dir, int expected) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (true) {
      final records = [
        for (final file in dir.listSync().whereType<File>())
          file.readAsStringSync(),
      ];
      final complete = records.length >= expected &&
          records.every((record) => record.isNotEmpty);
      if (complete || DateTime.now().isAfter(deadline)) return records;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  static void _write(List<String> args, String value) =>
      File('${args.single}${Platform.pathSeparator}${Isolate.current.hashCode}')
          .writeAsStringSync(value);
}
