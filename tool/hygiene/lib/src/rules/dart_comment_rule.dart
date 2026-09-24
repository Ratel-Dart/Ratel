import 'package:analyzer/dart/ast/token.dart';

import '../rule_id.dart';
import '../source_file.dart';
import '../violation.dart';
import 'hygiene_rule.dart';

final class DartCommentRule implements HygieneRule {
  const DartCommentRule();

  @override
  RuleId get id => RuleId.dartComment;

  @override
  bool appliesTo(SourceFile file) => file.isDart;

  @override
  List<Violation> check(SourceFile file) {
    final violations = <Violation>[];
    Token? token = file.unit.beginToken;
    while (token != null) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        violations.add(Violation(
          path: file.path,
          line: file.lineOf(comment.offset),
          rule: id,
          message: 'Comments are not allowed.',
        ));
        comment = comment.next;
      }
      if (token.type == TokenType.EOF) break;
      token = token.next;
    }
    return violations;
  }
}
