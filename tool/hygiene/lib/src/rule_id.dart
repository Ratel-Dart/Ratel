enum RuleId {
  dartComment('dart-comment'),
  configComment('config-comment'),
  singleDeclaration('single-declaration'),
  looseMember('loose-member'),
  fileName('file-name'),
  packageLayout('package-layout'),
  partDirective('part-directive');

  const RuleId(this.id);

  final String id;

  static RuleId? parse(String value) {
    for (final rule in values) {
      if (rule.id == value) return rule;
    }
    return null;
  }
}
