import 'package:yaml/yaml.dart';

abstract final class PubspecReader {
  static String? name(String pubspec) => _string(pubspec, 'name');

  static String? version(String pubspec) => _string(pubspec, 'version');

  static bool declaresDependency(String pubspec, String package) {
    final document = _document(pubspec);
    if (document == null) return false;
    for (final section in const ['dependencies', 'dev_dependencies']) {
      final dependencies = document[section];
      if (dependencies is YamlMap && dependencies.containsKey(package)) {
        return true;
      }
    }
    return false;
  }

  static String? _string(String pubspec, String key) {
    final value = _document(pubspec)?[key];
    return value is String ? value : null;
  }

  static YamlMap? _document(String pubspec) {
    try {
      final document = loadYaml(pubspec);
      return document is YamlMap ? document : null;
    } on YamlException {
      return null;
    }
  }
}
