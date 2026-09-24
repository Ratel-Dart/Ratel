import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;

import 'analysis/controller_scanner.dart';
import 'analysis/dto_collector.dart';
import 'analysis/entry_signature_reader.dart';
import 'diagnostics/diagnostic_codes.dart';
import 'diagnostics/diagnostic_severity.dart';
import 'diagnostics/ratel_diagnostic.dart';
import 'emit/dev_watchdog_emitter.dart';
import 'emit/entry_emitter.dart';
import 'emit/import_uris.dart';
import 'emit/manifest_emitter.dart';
import 'generated_file.dart';
import 'generation_result.dart';
import 'model/entry_signature.dart';
import 'model/generation_mode.dart';
import 'model/scanned_app.dart';
import 'project_analyzer.dart';
import 'scan_scope.dart';

final class GenerationRun {
  GenerationRun({
    required this.analyzer,
    required this.packageName,
    required this.mode,
    String? entrypoint,
  }) : entrypoint =
            entrypoint == null ? null : p.normalize(p.absolute(entrypoint));

  final ProjectAnalyzer analyzer;
  final String packageName;
  final GenerationMode mode;
  final String? entrypoint;

  String get root => analyzer.root;

  String get outputDirectory => p.join(root, '.dart_tool', 'ratel', mode.name);

  String get entryFileName =>
      '${p.basenameWithoutExtension(entrypoint ?? 'main')}.dart';

  String get entryPath => p.join(outputDirectory, entryFileName);

  Future<GenerationResult> run() async {
    final diagnostics = <RatelDiagnostic>[];
    final libraries = await _libraries();
    final controllers = [
      for (final library in libraries)
        ...ControllerScanner.scan(library, diagnostics),
    ];
    final app = ScannedApp(
      controllers: controllers,
      dtos: DtoCollector.collect(controllers, diagnostics),
    );

    final entry = entrypoint;
    EntrySignature? signature;
    final roots = [...libraries];
    if (entry != null) {
      final result = await analyzer.session.getResolvedLibrary(entry);
      if (result is ResolvedLibraryResult) {
        roots.add(result.element);
        signature = EntrySignatureReader.read(result.element, diagnostics);
      }
    }
    diagnostics.addAll(await _analyzerErrors(roots));

    if (app.controllers.isEmpty) {
      diagnostics.add(RatelDiagnostic(
        code: DiagnosticCodes.noControllers,
        message: 'No @Controller classes were found in lib/ or next to the '
            'entrypoint.',
        path: root,
        line: 1,
        column: 1,
        severity: DiagnosticSeverity.warning,
      ));
    }

    if (diagnostics.any((diagnostic) => diagnostic.isError)) {
      return GenerationResult(
          app: app, files: const [], diagnostics: diagnostics);
    }

    final uris = ImportUris(outputDirectory);
    final files = [
      GeneratedFile(
        EntryEmitter.manifestFile,
        ManifestEmitter(uris).emit(app),
      ),
      if (entry != null && signature != null && mode != GenerationMode.test)
        GeneratedFile(
          entryFileName,
          EntryEmitter.emit(
            entrypointImport: _importFor(entry, uris),
            signature: signature,
            watchdog: mode == GenerationMode.dev,
          ),
        ),
      if (mode == GenerationMode.dev)
        GeneratedFile(DevWatchdogEmitter.file, DevWatchdogEmitter.emit()),
    ];
    return GenerationResult(app: app, files: files, diagnostics: diagnostics);
  }

  Future<List<LibraryElement>> _libraries() async {
    final libraries = <LibraryElement>[];
    for (final path in ScanScope.files(root, entrypoint: entrypoint)) {
      final result = await analyzer.session.getResolvedLibrary(path);
      if (result is ResolvedLibraryResult) libraries.add(result.element);
    }
    return libraries;
  }

  String _importFor(String path, ImportUris uris) {
    final lib = p.join(root, 'lib');
    if (p.isWithin(lib, path)) {
      final inside = p.url.joinAll(p.split(p.relative(path, from: lib)));
      return 'package:$packageName/$inside';
    }
    return uris.relativeFile(path);
  }

  Future<List<RatelDiagnostic>> _analyzerErrors(
    List<LibraryElement> roots,
  ) async {
    final seen = <String>{};
    final queue = [...roots];
    final errors = <RatelDiagnostic>[];
    while (queue.isNotEmpty) {
      final library = queue.removeLast();
      if (!_isProjectLocal(library.uri)) continue;
      final path = library.firstFragment.source.fullName;
      if (!seen.add(path)) continue;
      for (final fragment in library.fragments) {
        for (final import in fragment.libraryImports) {
          final imported = import.importedLibrary;
          if (imported != null) queue.add(imported);
        }
        for (final export in fragment.libraryExports) {
          final exported = export.exportedLibrary;
          if (exported != null) queue.add(exported);
        }
      }
      final result = await analyzer.session.getResolvedLibrary(path);
      if (result is! ResolvedLibraryResult) continue;
      for (final unit in result.units) {
        for (final diagnostic in unit.diagnostics) {
          if (diagnostic.severity != Severity.error) continue;
          final location = unit.lineInfo.getLocation(diagnostic.offset);
          errors.add(RatelDiagnostic(
            code: diagnostic.diagnosticCode.lowerCaseName,
            message: _explained(diagnostic),
            path: unit.path,
            line: location.lineNumber,
            column: location.columnNumber,
          ));
        }
      }
    }
    return errors;
  }

  static String _explained(Diagnostic diagnostic) {
    final message = diagnostic.message;
    if (message.contains("'RatelHandler'")) {
      return '$message RatelHandler was removed: annotate the class with '
          '@Controller() instead of extending it.';
    }
    if (message.contains("'Json'") &&
        diagnostic.diagnosticCode.lowerCaseName.startsWith('undefined')) {
      return '$message @Json was removed: Ratel generates JSON codecs from '
          'route signatures; delete the annotation.';
    }
    return message;
  }

  bool _isProjectLocal(Uri uri) {
    if (uri.isScheme('package')) {
      return uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first == packageName;
    }
    if (uri.isScheme('file')) return p.isWithin(root, uri.toFilePath());
    return false;
  }
}
