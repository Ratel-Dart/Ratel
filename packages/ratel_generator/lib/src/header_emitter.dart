import 'package:build/build.dart';

import 'generation_context.dart';
import 'ratel_library.dart';

String emitHeader(
  RatelLibrary scanned,
  GenerationContext ctx,
  BuildStep buildStep,
) {
  final header = StringBuffer();
  if (scanned.needsRuntimeImport) {
    header.writeln("import 'package:ratel/ratel.dart' as _r;");
  }
  if (scanned.needsOrmImport) {
    header.writeln("import 'package:ratel_orm/ratel_orm.dart' as _orm;");
  }
  header.writeln("import '${buildStep.inputId.pathSegments.last}';");
  for (final entry in ctx.imports.entries) {
    header.writeln("import '${entry.key}' as ${entry.value};");
  }
  return header.toString();
}
