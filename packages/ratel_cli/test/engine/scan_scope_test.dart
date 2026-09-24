import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/scan_scope.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ratel_scan');
    for (final relative in [
      'lib/src/build/ping.dart',
      'lib/models/item.dart',
      'lib/models/item.ratel.dart',
      'lib/.hidden/secret.dart',
      'bin/server.dart',
      'bin/tools/health.dart',
      'test/item_test.dart',
    ]) {
      File(p.join(root.path, relative))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
    }
  });

  tearDown(() => root.delete(recursive: true));

  test('scans lib and the entrypoint folder, nested build folders included',
      () {
    final found = ScanScope.files(
      root.path,
      entrypoint: p.join(root.path, 'bin', 'server.dart'),
    ).map((path) => p.split(p.relative(path, from: root.path)).join('/'));

    expect(
      found,
      unorderedEquals([
        'lib/src/build/ping.dart',
        'lib/models/item.dart',
        'bin/server.dart',
        'bin/tools/health.dart',
      ]),
    );
  });
}
