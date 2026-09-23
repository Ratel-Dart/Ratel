import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/ratel_generator.dart';

/// Factory for the Ratel code generator (wired in `build.yaml`).
///
/// Emits a standalone `<file>.ratel.dart` library rather than a `part`, so
/// applications never declare a `part` directive.
Builder ratelBuilder(BuilderOptions options) => LibraryBuilder(
      RatelGenerator(),
      generatedExtension: '.ratel.dart',
    );
