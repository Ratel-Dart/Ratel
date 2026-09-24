import 'package:analyzer/dart/ast/ast.dart';

import '../rule_id.dart';
import '../source_file.dart';
import '../violation.dart';
import 'hygiene_rule.dart';

final class PartDirectiveRule implements HygieneRule {
  const PartDirectiveRule();

  @override
  RuleId get id => RuleId.partDirective;

  @override
  bool appliesTo(SourceFile file) => file.isDart;

  @override
  List<Violation> check(SourceFile file) => [
        for (final directive in file.unit.directives)
          if (directive is PartDirective || directive is PartOfDirective)
            Violation(
              path: file.path,
              line: file.lineOf(directive.offset),
              rule: id,
              message: 'part files are not allowed.',
            ),
      ];
}
