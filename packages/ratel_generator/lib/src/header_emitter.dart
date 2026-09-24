import 'package:build/build.dart';

import 'generation_context.dart';

String emitHeader(GenerationContext ctx, BuildStep buildStep) {
  final header = StringBuffer()
    ..writeln("import 'package:ratel/ratel.dart' as _r;")
    ..writeln("import '${buildStep.inputId.pathSegments.last}';");
  for (final entry in ctx.imports.entries) {
    header.writeln("import '${entry.key}' as ${entry.value};");
  }
  return header.toString();
}
