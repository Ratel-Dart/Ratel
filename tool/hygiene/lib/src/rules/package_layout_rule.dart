import '../rule_id.dart';
import '../source_file.dart';
import '../violation.dart';
import 'hygiene_rule.dart';
import 'single_declaration_rule.dart';

final class PackageLayoutRule implements HygieneRule {
  const PackageLayoutRule();

  @override
  RuleId get id => RuleId.packageLayout;

  @override
  bool appliesTo(SourceFile file) => file.isDart;

  @override
  List<Violation> check(SourceFile file) {
    if (!file.isLibraryPackage) return const [];
    final segments = file.segmentsInPackage;
    if (segments.first != 'lib') return const [];
    final exportOnly = SingleDeclarationRule.isExportOnly(file.unit);
    if (segments.length == 2 && !exportOnly) {
      return [
        _violation(file, 'A library in lib/ only exports lib/src files.')
      ];
    }
    if (segments.length > 2 && segments[1] != 'src') {
      return [_violation(file, 'Implementation files live under lib/src/.')];
    }
    if (segments.length > 2 && exportOnly) {
      return [
        _violation(file, 'lib/src holds no barrels; import files directly.')
      ];
    }
    return const [];
  }

  Violation _violation(SourceFile file, String message) =>
      Violation(path: file.path, line: 1, rule: id, message: message);
}
