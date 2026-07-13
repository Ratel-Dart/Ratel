import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/controller_generator.dart';
import 'src/json_generator.dart';
import 'src/row_mapper_generator.dart';

/// Factory for the Ratel code generators (wired in `build.yaml`): `@Json`
/// serialization, controller route tables and `@Column` row mappers.
Builder jsonBuilder(BuilderOptions options) => SharedPartBuilder(
      [JsonGenerator(), ControllerGenerator(), RowMapperGenerator()],
      'ratel_json',
    );
