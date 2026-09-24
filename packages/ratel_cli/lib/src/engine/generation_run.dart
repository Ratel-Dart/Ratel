import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;

import 'analysis/controller_scanner.dart';
import 'analysis/element_queries.dart';
import 'analysis/entry_signature_reader.dart';
import 'analysis/json_scanner.dart';
import 'analysis/ratel_annotations.dart';
import 'diagnostics/diagnostic_codes.dart';
import 'diagnostics/diagnostic_severity.dart';
import 'diagnostics/element_diagnostics.dart';
import 'diagnostics/ratel_diagnostic.dart';
import 'emit/entry_emitter.dart';
import 'emit/import_uris.dart';
import 'emit/manifest_emitter.dart';
import 'generated_file.dart';
import 'generation_result.dart';
import 'model/entry_signature.dart';
import 'model/generation_mode.dart';
import 'model/parameter_source.dart';
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

  Future<GenerationResult> run() async {
    final diagnostics = <RatelDiagnostic>[];
    final libraries = await _libraries();
    final app = ScannedApp(
      controllers: [
        for (final library in libraries)
          ...ControllerScanner.scan(library, diagnostics),
      ],
      jsonClasses: [
        for (final library in libraries)
          ...JsonScanner.scan(library, diagnostics),
      ],
    );
    _checkBodies(app, diagnostics);

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
          '${p.basenameWithoutExtension(entry)}.dart',
          EntryEmitter.emit(
            entrypointImport: _importFor(entry, uris),
            signature: signature,
          ),
        ),
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

  void _checkBodies(ScannedApp app, List<RatelDiagnostic> diagnostics) {
    final codecs = {for (final json in app.jsonClasses) json.element};
    for (final controller in app.controllers) {
      for (final route in controller.routes) {
        for (final parameter in route.parameters) {
          if (parameter.source != ParameterSource.body) continue;
          final element = parameter.type.element;
          final name = parameter.type.getDisplayString();
          if (element is! ClassElement ||
              !RatelAnnotations.has(element, 'Json')) {
            diagnostics.add(ElementDiagnostics.at(
              parameter.element,
              DiagnosticCodes.bodyNotJson,
              'The @Body() type $name is not a class annotated with @Json(), '
              'so no decoder exists for it. Add @Json() to $name.',
            ));
          } else if (!ElementQueries.canConstruct(element)) {
            diagnostics.add(ElementDiagnostics.at(
              parameter.element,
              DiagnosticCodes.bodyNotConstructible,
              'The @Body() type $name has no constructor callable without '
              'arguments, so it cannot be decoded. Give $name a constructor '
              'whose parameters are all optional.',
            ));
          } else if (!codecs.contains(element)) {
            diagnostics.add(ElementDiagnostics.at(
              parameter.element,
              DiagnosticCodes.bodyOutsideProject,
              'The @Body() type $name is declared outside this project, so '
              'Ratel does not generate its codec. Declare the model in this '
              "project's lib/.",
            ));
          }
        }
      }
    }
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
            message: diagnostic.message,
            path: unit.path,
            line: location.lineNumber,
            column: location.columnNumber,
          ));
        }
      }
    }
    return errors;
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
