import 'package:analyzer/dart/ast/ast.dart';

import '../rule_id.dart';
import '../source_file.dart';
import '../violation.dart';
import 'hygiene_rule.dart';

final class LooseMemberRule implements HygieneRule {
  const LooseMemberRule();

  @override
  RuleId get id => RuleId.looseMember;

  @override
  bool appliesTo(SourceFile file) => file.isDart;

  @override
  List<Violation> check(SourceFile file) {
    final inLib = file.segmentsInPackage.first == 'lib';
    final violations = <Violation>[];
    for (final declaration in file.unit.declarations) {
      if (declaration is TopLevelVariableDeclaration) {
        violations.add(_violation(
          file,
          declaration,
          'Top-level variables are not allowed; make them static members.',
        ));
      } else if (declaration is FunctionDeclaration) {
        final isMain = declaration.name.lexeme == 'main';
        if (!isMain) {
          violations.add(_violation(
            file,
            declaration,
            'Top-level functions are not allowed; make '
            '${declaration.name.lexeme} a static member of a class.',
          ));
        } else if (inLib && file.isLibraryPackage) {
          violations.add(_violation(
            file,
            declaration,
            'main belongs in bin/, test/, example/ or tool/, not lib/.',
          ));
        }
      }
    }
    return violations;
  }

  Violation _violation(SourceFile file, AstNode node, String message) =>
      Violation(
        path: file.path,
        line: file.lineOf(node.offset),
        rule: id,
        message: message,
      );
}
