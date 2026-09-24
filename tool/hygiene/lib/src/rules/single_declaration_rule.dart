import 'package:analyzer/dart/ast/ast.dart';

import '../rule_id.dart';
import '../source_file.dart';
import '../violation.dart';
import 'hygiene_rule.dart';

final class SingleDeclarationRule implements HygieneRule {
  const SingleDeclarationRule();

  @override
  RuleId get id => RuleId.singleDeclaration;

  @override
  bool appliesTo(SourceFile file) => file.isDart;

  @override
  List<Violation> check(SourceFile file) {
    final declarations = file.unit.declarations;
    if (declarations.length > 1) {
      return [
        for (final extra in declarations.skip(1))
          Violation(
            path: file.path,
            line: file.lineOf(extra.offset),
            rule: id,
            message: 'A file holds exactly one top-level declaration.',
          ),
      ];
    }
    if (declarations.isEmpty && !isExportOnly(file.unit)) {
      return [
        Violation(
          path: file.path,
          line: 1,
          rule: id,
          message: 'A file without declarations may only export libraries.',
        ),
      ];
    }
    return const [];
  }

  static bool isExportOnly(CompilationUnit unit) =>
      unit.declarations.isEmpty &&
      unit.directives.isNotEmpty &&
      unit.directives.every((directive) => directive is ExportDirective);
}
