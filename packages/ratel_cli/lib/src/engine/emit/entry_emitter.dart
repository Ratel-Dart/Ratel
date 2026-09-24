import '../model/entry_signature.dart';
import 'dev_watchdog_emitter.dart';
import 'import_allocator.dart';
import 'manifest_emitter.dart';

abstract final class EntryEmitter {
  static const manifestFile = 'manifest.dart';

  static String emit({
    required String entrypointImport,
    required EntrySignature signature,
    bool watchdog = false,
  }) {
    const r = ImportAllocator.runtimePrefix;
    final arguments = signature.takesArguments ? 'args' : '';
    final call = 'entrypoint.main($arguments)';
    final invocation = signature.returnsFuture ? 'await $call' : call;
    final buffer = StringBuffer()
      ..writeln("import '${ImportAllocator.runtimeUri}' as $r;")
      ..writeln()
      ..writeln("import '$entrypointImport' as entrypoint;")
      ..writeln("import '$manifestFile';");
    if (watchdog) {
      buffer.writeln("import '${DevWatchdogEmitter.file}';");
    }
    buffer
      ..writeln()
      ..writeln('Future<void> main(List<String> args) async {');
    if (watchdog) {
      buffer.writeln('  ${DevWatchdogEmitter.className}.attach();');
    }
    buffer
      ..writeln(
          '  $r.RatelRuntime.install(${ManifestEmitter.className}.manifest);')
      ..writeln('  $invocation;')
      ..writeln('}');
    return buffer.toString();
  }
}
