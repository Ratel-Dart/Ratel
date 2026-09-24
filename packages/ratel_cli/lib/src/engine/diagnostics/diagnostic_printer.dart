import 'package:path/path.dart' as p;

import 'ratel_diagnostic.dart';

abstract final class DiagnosticPrinter {
  static const limit = 20;

  static String format(List<RatelDiagnostic> diagnostics, String root) {
    final lines = <String>[];
    for (final diagnostic in diagnostics.take(limit)) {
      final path = p.isWithin(root, diagnostic.path)
          ? p.relative(diagnostic.path, from: root)
          : diagnostic.path;
      lines.add(
        '  ${diagnostic.severity.name} - $path:${diagnostic.line}:'
        '${diagnostic.column} - ${diagnostic.message} - ${diagnostic.code}',
      );
    }
    if (diagnostics.length > limit) {
      lines.add('  ... and ${diagnostics.length - limit} more');
    }
    return lines.join('\n');
  }
}
