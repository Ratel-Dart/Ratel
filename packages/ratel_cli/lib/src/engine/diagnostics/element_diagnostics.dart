import 'package:analyzer/dart/element/element.dart';

import 'diagnostic_severity.dart';
import 'ratel_diagnostic.dart';

abstract final class ElementDiagnostics {
  static RatelDiagnostic at(
    Element element,
    String code,
    String message, {
    DiagnosticSeverity severity = DiagnosticSeverity.error,
  }) {
    final fragment = element.firstFragment;
    final library = fragment.libraryFragment;
    final offset = fragment.nameOffset ?? fragment.offset;
    final location = library?.lineInfo.getLocation(offset);
    return RatelDiagnostic(
      code: code,
      message: message,
      path: library?.source.fullName ?? '',
      line: location?.lineNumber ?? 1,
      column: location?.columnNumber ?? 1,
      severity: severity,
    );
  }
}
