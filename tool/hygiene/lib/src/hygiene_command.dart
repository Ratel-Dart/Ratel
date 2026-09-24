import 'dart:io';

import 'hygiene_options.dart';
import 'rules/config_comment_rule.dart';
import 'rules/dart_comment_rule.dart';
import 'rules/file_name_rule.dart';
import 'rules/hygiene_rule.dart';
import 'rules/loose_member_rule.dart';
import 'rules/package_layout_rule.dart';
import 'rules/part_directive_rule.dart';
import 'rules/single_declaration_rule.dart';
import 'source_file.dart';
import 'source_walker.dart';
import 'violation.dart';

abstract final class HygieneCommand {
  static const rules = <HygieneRule>[
    DartCommentRule(),
    ConfigCommentRule(),
    SingleDeclarationRule(),
    LooseMemberRule(),
    FileNameRule(),
    PackageLayoutRule(),
    PartDirectiveRule(),
  ];

  static Future<int> run(List<String> arguments) async {
    final HygieneOptions options;
    try {
      options = HygieneOptions.parse(arguments);
    } on FormatException catch (error) {
      stderr
        ..writeln(error.message)
        ..writeln(HygieneOptions.usage);
      return 64;
    }
    final violations = check(options);
    final from = Directory.current.path;
    for (final violation in violations) {
      stdout.writeln(violation.format(from));
    }
    stdout.writeln(
      violations.isEmpty
          ? 'No hygiene violations.'
          : '${violations.length} hygiene violations.',
    );
    return violations.isEmpty ? 0 : 1;
  }

  static List<Violation> check(HygieneOptions options) {
    final violations = <Violation>[];
    for (final path in SourceWalker.files(options.paths)) {
      final file = SourceFile(path);
      for (final rule in rules) {
        if (!options.includes(rule.id) || !rule.appliesTo(file)) continue;
        violations.addAll(rule.check(file));
      }
    }
    return violations;
  }
}
