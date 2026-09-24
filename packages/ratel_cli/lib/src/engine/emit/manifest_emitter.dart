import 'package:analyzer/dart/element/type.dart';

import '../model/parameter_source.dart';
import '../model/scanned_app.dart';
import '../model/scanned_controller.dart';
import '../model/scanned_json_class.dart';
import '../model/scanned_parameter.dart';
import 'dart_literal.dart';
import 'import_allocator.dart';
import 'import_uris.dart';
import 'name_allocator.dart';
import 'type_emitter.dart';

final class ManifestEmitter {
  ManifestEmitter(ImportUris uris) : _imports = ImportAllocator(uris) {
    _types = TypeEmitter(_imports);
  }

  static const className = 'RatelAppManifest';

  final ImportAllocator _imports;
  late final TypeEmitter _types;
  final NameAllocator _names = NameAllocator();
  final List<String> _members = [];

  static const _r = ImportAllocator.runtimePrefix;

  String emit(ScannedApp app) {
    final controllers = [for (final c in app.controllers) _controller(c)];
    final codecs = [for (final j in app.jsonClasses) _codec(j)];
    final body = StringBuffer()
      ..writeln('abstract final class $className {')
      ..writeln(
          '  static const $_r.RatelManifest manifest = $_r.RatelManifest(')
      ..writeln('    controllers: [')
      ..writeAll(controllers)
      ..writeln('    ],')
      ..writeln('    jsonCodecs: [')
      ..writeAll(codecs)
      ..writeln('    ],')
      ..writeln('  );');
    for (final member in _members) {
      body
        ..writeln()
        ..write(member);
    }
    body.writeln('}');
    return '${_imports.directives().join('\n\n')}\n\n$body';
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
          ..writeln('            path: ${DartLiteral.string(socket.path)},')
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

  String _codec(ScannedJsonClass json) {
    final type = _types.nonNullable(json.element.thisType);
    final className = json.element.name ?? '';
    final encode = _names.allocate([className, 'ToJson']);
    final entries = [
      for (final field in json.encoded)
        '      ${DartLiteral.string(field)}: value.$field,',
    ];
    _members.add(
      '  static Map<String, Object?> $encode($type value) =>\n'
      '      <String, Object?>{\n${entries.join('\n')}\n      };\n',
    );
    final buffer = StringBuffer()
      ..writeln('      $_r.JsonCodecDefinition<$type>(')
      ..writeln('        encode: $encode,');
    if (json.isConstructible) {
      final decode = _names.allocate([className, 'FromJson']);
      final assignments = StringBuffer();
      for (final field in json.decoded) {
        final key = DartLiteral.string(field.name);
        assignments
          ..writeln('    if (json.containsKey($key)) {')
          ..writeln(
            '      value.${field.name} = json[$key] as ${_types.emit(field.type)};',
          )
          ..writeln('    }');
      }
      _members.add(
        '  static $type $decode(Map<String, Object?> json) {\n'
        '    final value = $type();\n'
        '$assignments'
        '    return value;\n'
        '  }\n',
      );
      buffer.writeln('        decode: $decode,');
    }
    buffer.writeln('      ),');
    return buffer.toString();
  }
}
