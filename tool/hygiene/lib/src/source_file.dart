import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

final class SourceFile {
  SourceFile(this.path) : text = File(path).readAsStringSync();

  final String path;
  final String text;

  late final CompilationUnit unit =
      parseString(content: text, path: path, throwIfDiagnostics: false).unit;

  late final String? packageRoot = _packageRoot(p.dirname(path));

  List<String> get segmentsInPackage {
    final root = packageRoot;
    if (root == null) return p.split(path);
    return p.split(p.relative(path, from: root));
  }

  bool get isDart => path.endsWith('.dart');

  late final bool isLibraryPackage = _isLibraryPackage(packageRoot);

  int lineOf(int offset) => unit.lineInfo.getLocation(offset).lineNumber;

  static final _name = RegExp(r'^name:\s*(\S+)\s*$', multiLine: true);

  static bool _isLibraryPackage(String? root) {
    if (root == null) return false;
    final pubspec = File(p.join(root, 'pubspec.yaml')).readAsStringSync();
    final name = _name.firstMatch(pubspec)?.group(1);
    return name != null && File(p.join(root, 'lib', '$name.dart')).existsSync();
  }

  static String? _packageRoot(String directory) {
    var current = directory;
    while (true) {
      if (File(p.join(current, 'pubspec.yaml')).existsSync()) return current;
      final parent = p.dirname(current);
      if (parent == current) return null;
      current = parent;
    }
  }
}
