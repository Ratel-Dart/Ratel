import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'pubspec.dart';

const _fallbackVersion = '2.0.0-dev.8';

const generatorVersion = '0.1.0-dev.1';

Future<String> ratelVersion() async {
  final resolved =
      await Isolate.resolvePackageUri(Uri.parse('package:ratel/ratel.dart'));
  if (resolved == null || !resolved.isScheme('file')) return _fallbackVersion;
  final pubspec = File(
    p.join(p.dirname(p.dirname(resolved.toFilePath())), 'pubspec.yaml'),
  );
  if (!pubspec.existsSync()) return _fallbackVersion;
  return readVersion(pubspec.readAsStringSync()) ?? _fallbackVersion;
}
