import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'controller_emitter.dart';
import 'element_queries.dart';
import 'generation_context.dart';
import 'header_emitter.dart';
import 'json_emitter.dart';
import 'library_scanner.dart';
import 'row_mapper_emitter.dart';

class RatelGenerator extends Generator {
  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final scanned = scanLibrary(library);
    if (scanned.isEmpty) return null;

    final ctx = GenerationContext(library, buildStep);
    final declarations = StringBuffer();
    final registrations = <String>[];

    for (final element in scanned.jsonClasses) {
      declarations
        ..writeln(emitToJson(element))
        ..writeln();
      final fromJson = emitFromJson(element);
      if (fromJson != null) {
        declarations
          ..writeln(fromJson)
          ..writeln();
      }
      registrations.add(
        '  _r.RatelJson.register<${element.displayName}>'
        '(\$${element.displayName}ToJson);',
      );
    }

    for (final entry in scanned.entities.entries) {
      declarations
        ..writeln(emitFromRow(entry.key, entry.value))
        ..writeln();
      registrations.add(
        '  _orm.RatelRowMappers.register<${entry.key.displayName}>'
        '(\$${entry.key.displayName}FromRow);',
      );
    }

    for (final element in scanned.controllers) {
      declarations
        ..writeln(emitRoutes(element, ctx))
        ..writeln();
      if (canConstruct(element)) {
        registrations.add(
          '  _r.RatelControllers.registerDefault<${element.displayName}>'
          '(${element.displayName}.new);',
        );
      }
      registrations.add(
        '  \$${element.displayName}Routes'
        '(() => _r.RatelControllers.create<${element.displayName}>());',
      );
    }

    return '${emitHeader(scanned, ctx, buildStep)}\n'
        '$declarations'
        'void \$registerRatel() {\n'
        '${registrations.join('\n')}\n'
        '}';
  }
}
