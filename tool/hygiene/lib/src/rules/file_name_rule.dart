import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../rule_id.dart';
import '../snake_case.dart';
import '../source_file.dart';
import '../violation.dart';
import 'hygiene_rule.dart';

final class FileNameRule implements HygieneRule {
  const FileNameRule();

  @override
  RuleId get id => RuleId.fileName;

  @override
  bool appliesTo(SourceFile file) => file.isDart;

  @override
  List<Violation> check(SourceFile file) {
    final declarations = file.unit.declarations;
    if (declarations.length != 1) return const [];
    final name = _typeName(declarations.single);
    if (name == null) return const [];
    if (name.startsWith('_') || name.isEmpty) {
      return [
        Violation(
          path: file.path,
          line: file.lineOf(declarations.single.offset),
          rule: id,
          message: 'The declaration of a file must be public.',
        ),
      ];
    }
    final expected = '${SnakeCase.of(name)}.dart';
    if (p.basename(file.path) == expected) return const [];
    return [
      Violation(
        path: file.path,
        line: file.lineOf(declarations.single.offset),
        rule: id,
        message: 'The file declaring $name is named $expected.',
      ),
    ];
  }

  static String? _typeName(CompilationUnitMember declaration) =>
      switch (declaration) {
        ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
        MixinDeclaration(:final name) => name.lexeme,
        EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
        ExtensionDeclaration(:final name) => name?.lexeme ?? '',
        ExtensionTypeDeclaration(:final namePart) => namePart.typeName.lexeme,
        TypeAlias(:final name) => name.lexeme,
        _ => null,
      };
}
