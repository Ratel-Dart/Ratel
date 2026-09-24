import 'rule_id.dart';

final class HygieneOptions {
  const HygieneOptions({
    required this.paths,
    required this.only,
  });

  final List<String> paths;
  final Set<RuleId> only;

  static const usage = 'Usage: check.dart [--only <rule>]... <path>...\n'
      'Rules: dart-comment, config-comment, single-declaration, loose-member, '
      'file-name, package-layout, part-directive';

  bool includes(RuleId rule) => only.isEmpty || only.contains(rule);

  static HygieneOptions parse(List<String> arguments) {
    final paths = <String>[];
    final only = <RuleId>{};
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--only') {
        if (index + 1 >= arguments.length) {
          throw FormatException('$argument needs a value.');
        }
        final value = arguments[++index];
        final rule = RuleId.parse(value);
        if (rule == null) throw FormatException('Unknown rule: $value');
        only.add(rule);
      } else if (argument.startsWith('--')) {
        throw FormatException('Unknown option: $argument');
      } else {
        paths.add(argument);
      }
    }
    return HygieneOptions(
      paths: paths.isEmpty ? const ['.'] : paths,
      only: only,
    );
  }
}
