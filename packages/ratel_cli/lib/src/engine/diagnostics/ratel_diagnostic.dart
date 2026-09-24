import 'diagnostic_severity.dart';

final class RatelDiagnostic {
  const RatelDiagnostic({
    required this.code,
    required this.message,
    required this.path,
    required this.line,
    required this.column,
    this.severity = DiagnosticSeverity.error,
  });

  final String code;
  final String message;
  final String path;
  final int line;
  final int column;
  final DiagnosticSeverity severity;

  bool get isError => severity == DiagnosticSeverity.error;
}
