import 'dart:io';

import 'package:test/test.dart';

abstract final class ClusterRunRecorder {
  static void record(List<String> args) {
    final name =
        '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';
    File('${args.first}/$name').writeAsStringSync('.');
  }

  static int runsIn(Directory dir) => dir.listSync().length;

  static Future<void> waitForRuns(Directory dir, int expected) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      if (runsIn(dir) >= expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('only ${runsIn(dir)} of $expected runs recorded');
  }
}
