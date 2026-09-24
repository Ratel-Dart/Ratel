import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/ratel_generator.dart';

Builder ratelBuilder(BuilderOptions options) => LibraryBuilder(
      RatelGenerator(),
      generatedExtension: '.ratel.dart',
    );
