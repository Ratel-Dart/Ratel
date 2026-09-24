import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

import 'orm_fixture.dart';

abstract final class OrmPackage {
  static Future<String>? _root;

  static Future<String> root() => _root ??= _resolve();

  static Future<String> _resolve() async {
    final local = OrmFixture.localOrm;
    if (local != null) return local;
    final temp = await Directory.systemTemp.createTemp('ratel_orm_resolve');
    try {
      final app = await OrmFixture.copy('orm_only', temp);
      final config = await findPackageConfig(app);
      final package = config?['ratel_orm'];
      if (package == null) throw StateError('pub get did not add ratel_orm.');
      return p.normalize(package.root.toFilePath());
    } finally {
      await temp.delete(recursive: true);
    }
  }
}
