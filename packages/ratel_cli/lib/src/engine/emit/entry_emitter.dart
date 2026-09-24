import '../../project/project_runtimes.dart';
import '../model/entry_signature.dart';
import 'dev_watchdog_emitter.dart';
import 'entity_manifest_emitter.dart';
import 'import_allocator.dart';
import 'manifest_emitter.dart';

abstract final class EntryEmitter {
  static String emit({
    required String entrypointImport,
    required EntrySignature signature,
    required ProjectRuntimes runtimes,
    bool watchdog = false,
  }) {
    final arguments = signature.takesArguments ? 'args' : '';
    final call = 'entrypoint.main($arguments)';
    final invocation = signature.returnsFuture ? 'await $call' : call;
    final buffer = StringBuffer();
    for (final directive in ImportAllocator.runtimeDirectives(runtimes)) {
      buffer.writeln(directive);
    }
    buffer
      ..writeln()
      ..writeln("import '$entrypointImport' as entrypoint;");
    if (runtimes.framework) {
      buffer.writeln("import '${ManifestEmitter.file}';");
    }
    if (watchdog) {
      buffer.writeln("import '${DevWatchdogEmitter.file}';");
    }
    if (runtimes.orm) {
      buffer.writeln("import '${EntityManifestEmitter.file}';");
    }
    buffer
      ..writeln()
      ..writeln('Future<void> main(List<String> args) async {');
    if (watchdog) {
      buffer.writeln('  await ${DevWatchdogEmitter.className}.attach();');
    }
    buffer
      ..write(installs(runtimes))
      ..writeln('  $invocation;')
      ..writeln('}');
    return buffer.toString();
  }

  static String installs(ProjectRuntimes runtimes) {
    final buffer = StringBuffer();
    if (runtimes.orm) {
      buffer.writeln(
        '  ${ImportAllocator.ormPrefix}.RatelOrmRuntime.install('
        '${EntityManifestEmitter.className}.manifest);',
      );
    }
    if (runtimes.framework) {
      buffer.writeln(
        '  ${ImportAllocator.runtimePrefix}.RatelRuntime.install('
        '${ManifestEmitter.className}.manifest);',
      );
    }
    return buffer.toString();
  }
}
