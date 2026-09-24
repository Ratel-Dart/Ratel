import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

abstract final class BuildHooksDetector {
  static Future<bool> hasHooks(String root) async {
    final config = await findPackageConfig(Directory(root));
    if (config == null) return false;
    for (final package in config.packages) {
      if (!package.root.isScheme('file')) continue;
      final hook =
          File(p.join(package.root.toFilePath(), 'hook', 'build.dart'));
      if (hook.existsSync()) return true;
    }
    return false;
  }
}
