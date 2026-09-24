import '../model/entry_signature.dart';
import 'import_allocator.dart';
import 'manifest_emitter.dart';

abstract final class EntryEmitter {
  static const manifestFile = 'manifest.dart';

  static String emit({
    required String entrypointImport,
    required EntrySignature signature,
  }) {
    const r = ImportAllocator.runtimePrefix;
    final arguments = signature.takesArguments ? 'args' : '';
    final call = 'entrypoint.main($arguments)';
    final invocation = signature.returnsFuture ? 'await $call' : call;
    return "import '${ImportAllocator.runtimeUri}' as $r;\n"
        '\n'
        "import '$entrypointImport' as entrypoint;\n"
        "import '$manifestFile';\n"
        '\n'
        'Future<void> main(List<String> args) async {\n'
        '  $r.RatelRuntime.install(${ManifestEmitter.className}.manifest);\n'
        '  $invocation;\n'
        '}\n';
  }
}
