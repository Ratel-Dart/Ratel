import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'generated_imports.dart';

class GenerationContext {
  GenerationContext(this.library, this.buildStep);

  final LibraryReader library;
  final BuildStep buildStep;
  final GeneratedImports imports = GeneratedImports();
}
