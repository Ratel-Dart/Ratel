import 'package:path/path.dart' as p;

import 'rule_id.dart';

final class Violation {
  const Violation({
    required this.path,
    required this.line,
    required this.rule,
    required this.message,
  });

  final String path;
  final int line;
  final RuleId rule;
  final String message;

  String format(String from) {
    final shown = p.split(p.relative(path, from: from)).join('/');
    return '$shown:$line [${rule.id}] $message';
  }
}
