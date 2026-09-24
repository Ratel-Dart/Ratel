import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';

abstract final class GeneratedCode {
  static Future<Map<String, List<String>>> problems(List<String> paths) async {
    final collection = AnalysisContextCollection(
      includedPaths: paths,
      sdkPath: DartSdk.root,
    );
    try {
      return {
        for (final path in paths)
          path: [
            for (final diagnostic in ((await collection
                    .contextFor(path)
                    .currentSession
                    .getResolvedUnit(path)) as ResolvedUnitResult)
                .diagnostics)
              if (diagnostic.severity != Severity.info) diagnostic.message,
          ],
      };
    } finally {
      await collection.dispose();
    }
  }

  static bool hasComments(String path) {
    final unit = parseString(content: File(path).readAsStringSync()).unit;
    Token? token = unit.beginToken;
    while (token != null && token.type != TokenType.EOF) {
      if (token.precedingComments != null) return true;
      token = token.next;
    }
    return false;
  }

  static List<CompilationUnitMember> declarations(String path) =>
      parseString(content: File(path).readAsStringSync()).unit.declarations;
}
