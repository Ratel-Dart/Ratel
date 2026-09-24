import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'entry_emitter.dart';
import 'import_allocator.dart';
import 'manifest_emitter.dart';

abstract final class SuiteWrapperEmitter {
  static const _test = 'package:test/test.dart';

  static String emit({
    required String suite,
    required String wrapperDirectory,
    required String manifestDirectory,
  }) {
    final unit = parseString(
      content: File(suite).readAsStringSync(),
      throwIfDiagnostics: false,
    ).unit;
    final annotations = _libraryAnnotations(unit);
    final annotationImports = _importsFor(annotations, unit);
    final main = _main(unit);
    const r = ImportAllocator.runtimePrefix;

    final buffer = StringBuffer();
    if (annotations.isNotEmpty) {
      for (final annotation in annotations) {
        buffer.writeln(annotation.toSource());
      }
      buffer
        ..writeln('library;')
        ..writeln();
    }
    buffer.writeln("import '${ImportAllocator.runtimeUri}' as $r;");
    for (final directive in annotationImports) {
      buffer.writeln(directive);
    }
    buffer
      ..writeln()
      ..writeln("import '${_relative(suite, wrapperDirectory)}' as suite;")
      ..writeln(
        "import '${_relative(p.join(manifestDirectory, EntryEmitter.manifestFile), wrapperDirectory)}';",
      )
      ..writeln()
      ..writeln('Future<void> main() async {')
      ..writeln(
          '  $r.RatelRuntime.install(${ManifestEmitter.className}.manifest);')
      ..writeln('  ${main.returnsFuture ? 'await ' : ''}suite.main();')
      ..writeln('}');
    return buffer.toString();
  }

  static List<Annotation> _libraryAnnotations(CompilationUnit unit) {
    for (final directive in unit.directives) {
      if (directive is LibraryDirective) return directive.metadata;
    }
    return const [];
  }

  static List<String> _importsFor(
    List<Annotation> annotations,
    CompilationUnit unit,
  ) {
    if (annotations.isEmpty) return const [];
    final prefixes = {
      for (final annotation in annotations)
        if (annotation.name case PrefixedIdentifier(:final prefix)) prefix.name,
    };
    final imports = <String>{};
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      final uri = directive.uri.stringValue;
      if (uri == null ||
          !(uri.startsWith('package:') || uri.startsWith('dart:'))) {
        continue;
      }
      final prefix = directive.prefix?.name;
      if (prefix != null && prefixes.contains(prefix)) {
        imports.add("import '$uri' as $prefix;");
      }
    }
    if (annotations.any((annotation) => annotation.name is SimpleIdentifier)) {
      imports.add("import '$_test';");
    }
    return imports.toList()..sort();
  }

  static ({bool returnsFuture}) _main(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.lexeme == 'main') {
        final returnType = declaration.returnType?.toSource() ?? '';
        final isAsync = declaration.functionExpression.body.isAsynchronous;
        return (returnsFuture: isAsync || returnType.startsWith('Future'));
      }
    }
    return (returnsFuture: false);
  }

  static String _relative(String path, String from) =>
      p.url.joinAll(p.split(p.relative(path, from: from)));
}
