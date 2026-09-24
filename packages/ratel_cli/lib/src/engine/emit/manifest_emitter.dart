import 'package:analyzer/dart/element/type.dart';

import '../../project/project_runtimes.dart';
import '../model/parameter_source.dart';
import '../model/scanned_app.dart';
import '../model/scanned_controller.dart';
import '../model/scanned_parameter.dart';
import 'dart_literal.dart';
import 'entity_manifest_emitter.dart';
import 'import_allocator.dart';
import 'import_uris.dart';
import 'json_codec_emitter.dart';
import 'name_allocator.dart';
import 'type_emitter.dart';

final class ManifestEmitter {
  ManifestEmitter(ImportUris uris, {bool entities = false})
      : _entities = entities,
        _imports = ImportAllocator(
          uris,
          runtimes: ProjectRuntimes(framework: true, orm: entities),
        ) {
    _types = TypeEmitter(_imports);
  }

  static const className = 'RatelAppManifest';
  static const file = 'ratel_app_manifest.dart';

  final bool _entities;
  final ImportAllocator _imports;
  late final TypeEmitter _types;
  final NameAllocator _names = NameAllocator();
  final List<String> _members = [];

  static const _r = ImportAllocator.runtimePrefix;
  static const _o = ImportAllocator.ormPrefix;

  String emit(ScannedApp app) {
    final controllers = [for (final c in app.controllers) _controller(c)];
    final codecs =
        JsonCodecEmitter(types: _types, names: _names).emit(app.dtos, _members);
    final body = StringBuffer()
      ..writeln('abstract final class $className {')
      ..writeln(
          '  static const $_r.RatelManifest manifest = $_r.RatelManifest(')
      ..writeln('    controllers: [')
      ..writeAll(controllers)
      ..writeln('    ],')
      ..writeln('    jsonCodecs: [')
      ..write(codecs)
      ..writeln('    ],');
    if (_entities) {
      final install = _names.allocate(['install', 'Entities']);
      body.writeln('    isolateSetup: [$install],');
      _members.add(
        '  static void $install() =>\n'
        '      $_o.RatelOrmRuntime.install('
        '${EntityManifestEmitter.className}.manifest);\n',
      );
    }
    body.writeln('  );');
    for (final member in _members) {
      body
        ..writeln()
        ..write(member);
    }
    body.writeln('}');
    final directives = _imports.directives(
      extra: {if (_entities) EntityManifestEmitter.file: null},
    );
    return '${directives.join('\n\n')}\n\n$body';
  }

  String _controller(ScannedController controller) {
    final type = _types.nonNullable(controller.element.thisType);
    final buffer = StringBuffer()
      ..writeln('      $_r.ControllerDefinition<$type>(');
    if (controller.isConstructible) {
      buffer.writeln('        create: $type.new,');
    }
    buffer.writeln('        routes: [');
    for (final route in controller.routes) {
      final invoker = _invoker(controller, route.methodName, route.parameters);
      buffer
        ..writeln('          $_r.RouteDefinition<$type>(')
        ..writeln("            method: '${route.verb}',")
        ..writeln('            path: ${DartLiteral.string(route.path)},');
      if (route.isProtected) {
        buffer.writeln('            isProtected: true,');
      }
      if (route.roles.isNotEmpty) {
        buffer.writeln(
          '            requiredRoles: ${DartLiteral.strings(route.roles)},',
        );
      }
      buffer
        ..write(_parameters(route.parameters, '            '))
        ..writeln('            invoke: $invoker,')
        ..writeln('          ),');
    }
    buffer.writeln('        ],');
    if (controller.sockets.isNotEmpty) {
      buffer.writeln('        sockets: [');
      for (final socket in controller.sockets) {
        final invoker =
            _invoker(controller, socket.methodName, socket.parameters);
        buffer
          ..writeln('          $_r.SocketDefinition<$type>(')
          ..writeln('            path: ${DartLiteral.string(socket.path)},');
        if (socket.isProtected) {
          buffer.writeln('            isProtected: true,');
        }
        if (socket.roles.isNotEmpty) {
          buffer.writeln(
            '            requiredRoles: ${DartLiteral.strings(socket.roles)},',
          );
        }
        buffer
          ..write(_parameters(socket.parameters, '            '))
          ..writeln('            invoke: $invoker,')
          ..writeln('          ),');
      }
      buffer.writeln('        ],');
    }
    buffer.writeln('      ),');
    return buffer.toString();
  }

  String _parameters(List<ScannedParameter> parameters, String indent) {
    final bound = parameters
        .where((parameter) => parameter.source != ParameterSource.unbound)
        .toList();
    if (bound.isEmpty) return '';
    final buffer = StringBuffer()..writeln('${indent}parameters: [');
    for (final parameter in bound) {
      buffer
        ..writeln('$indent  $_r.RouteParameter(')
        ..writeln(
          '$indent    name: ${DartLiteral.string(parameter.bindingName)},',
        )
        ..writeln(
          '$indent    location: $_r.ParameterLocation.${parameter.source.name},',
        )
        ..writeln('$indent    type: ${_types.nonNullable(parameter.type)},')
        ..writeln('$indent    isRequired: ${parameter.isRequired},')
        ..writeln('$indent  ),');
    }
    buffer.writeln('$indent],');
    return buffer.toString();
  }

  String _invoker(
    ScannedController controller,
    String methodName,
    List<ScannedParameter> parameters,
  ) {
    final type = _types.nonNullable(controller.element.thisType);
    final name = _names.allocate([controller.element.name ?? '', methodName]);
    final arguments = <String>[];
    var index = 0;
    for (final parameter in parameters) {
      final String value;
      if (parameter.source == ParameterSource.unbound) {
        if (parameter.isNamed && !parameter.element.isRequiredNamed) continue;
        value = 'null';
      } else {
        value = 'arguments[$index] as ${_types.emit(parameter.type)}';
        index++;
      }
      arguments
          .add(parameter.isNamed ? '${parameter.dartName}: $value' : value);
    }
    final call = 'controller.$methodName(${arguments.join(', ')})';
    final method = controller.element.getMethod(methodName);
    final returnsVoid = method?.returnType is VoidType;
    final signature =
        '  static Object? $name(\n    $type controller,\n    List<Object?> arguments,\n  )';
    _members.add(returnsVoid
        ? '$signature {\n    $call;\n    return null;\n  }\n'
        : '$signature =>\n      $call;\n');
    return name;
  }
}
