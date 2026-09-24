import 'dart:io';

import 'package:path/path.dart' as p;

import '../process/dart_process.dart';
import 'build_hooks_detector.dart';

abstract final class NativeCompiler {
  static Future<int> compile({
    required String root,
    required String entry,
  }) async {
    final stem = p.basenameWithoutExtension(entry);
    final binary = Platform.isWindows ? '$stem.exe' : stem;
    final build = p.join(root, 'build');
    Directory(build).createSync(recursive: true);
    final String output;
    final int code;
    if (await BuildHooksDetector.hasHooks(root)) {
      output = p.join(build, 'bundle', 'bin', binary);
      code = await DartProcess.run(
        ['build', 'cli', '--target', entry, '-o', build],
        workingDirectory: root,
      );
    } else {
      output = p.join(build, binary);
      code = await DartProcess.run(
        ['compile', 'exe', entry, '-o', output],
        workingDirectory: root,
      );
    }
    if (code == 0) stdout.writeln('Built ${p.relative(output, from: root)}');
    return code;
  }
}
