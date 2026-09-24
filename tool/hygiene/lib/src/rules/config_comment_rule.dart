import '../rule_id.dart';
import '../source_file.dart';
import '../source_walker.dart';
import '../violation.dart';
import 'hygiene_rule.dart';

final class ConfigCommentRule implements HygieneRule {
  const ConfigCommentRule();

  static final _quoted = RegExp(r'''"[^"]*"|'[^']*'|`[^`]*`''');
  static final _comment = RegExp(r'(^|\s)#');

  @override
  RuleId get id => RuleId.configComment;

  @override
  bool appliesTo(SourceFile file) => SourceWalker.isConfig(file.path);

  @override
  List<Violation> check(SourceFile file) {
    final violations = <Violation>[];
    final lines = file.text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      final unquoted = lines[index].replaceAll(_quoted, '');
      if (_comment.hasMatch(unquoted)) {
        violations.add(Violation(
          path: file.path,
          line: index + 1,
          rule: id,
          message: 'Comments are not allowed.',
        ));
      }
    }
    return violations;
  }
}
