import '../rule_id.dart';
import '../source_file.dart';
import '../violation.dart';

abstract interface class HygieneRule {
  RuleId get id;

  bool appliesTo(SourceFile file);

  List<Violation> check(SourceFile file);
}
