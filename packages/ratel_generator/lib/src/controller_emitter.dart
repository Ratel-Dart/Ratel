import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

import 'annotation_checkers.dart';
import 'constant_values.dart';
import 'generation_context.dart';
import 'injected_types.dart';
import 'parameter_emitter.dart';
import 'route_metadata_emitter.dart';
import 'route_path.dart';
import 'socket_emitter.dart';

String emitRoutes(ClassElement controller, GenerationContext ctx) {
  final name = controller.displayName;
  final prefix =
      readString(controllerChecker.firstAnnotationOf(controller), 'prefix') ??
          '';
  final classProtected = protectedChecker.firstAnnotationOf(controller);

  final registrations = <String>[];
  for (final method in controller.methods) {
    if (method.isStatic) continue;
    for (final (checker, verb) in verbCheckers) {
      final annotation = checker.firstAnnotationOf(method);
      if (annotation == null) continue;
      final path = readString(annotation, 'path') ?? '';
      registrations.add(
        _emitRegistration(
          method,
          verb,
          joinRoutePath(prefix, path),
          classProtected,
          ctx,
        ),
      );
    }

    final socket = emitSocketRegistration(method, prefix);
    if (socket != null) registrations.add(socket);
  }

  return 'void \$${name}Routes($name Function() factory) {\n'
      '  $name? instance;\n'
      '  $name controller() => instance ??= factory();\n'
      '${registrations.join('\n')}\n'
      '}';
}

String _emitRegistration(
  MethodElement method,
  String verb,
  String fullPath,
  DartObject? classProtected,
  GenerationContext ctx,
) {
  final methodProtected = protectedChecker.firstAnnotationOf(method);
  final methodPublic = publicChecker.hasAnnotationOf(method);
  final effective = methodProtected ?? (methodPublic ? null : classProtected);
  final isProtected = effective != null;
  final roles = readRoles(effective).map((r) => "'$r'").join(', ');

  final hasBody =
      method.formalParameters.any((p) => bodyChecker.hasAnnotationOf(p));
  final hasMultipart = method.formalParameters
      .any((p) => multipartChecker.isExactlyType(p.type));
  final args = method.formalParameters
      .map((param) => emitArgument(param, ctx))
      .join(', ');

  final buffer = StringBuffer()
    ..writeln('  _r.RatelHandler.register(_r.Route(')
    ..writeln("    path: '$fullPath',")
    ..writeln("    method: '$verb',")
    ..writeln('    isProtected: $isProtected,')
    ..writeln('    requiredRoles: const [$roles],')
    ..writeln(emitRouteParameters(method))
    ..writeln(emitRouteBodyType(method))
    ..writeln('    handler: ([ctxArg]) async {')
    ..writeln('      final ctx = ctxArg as _r.RequestContext;');
  if (hasMultipart) {
    buffer
      ..writeln('      final multipart = await _r.readMultipart(')
      ..writeln('          ctx.request, ctx.registry.maxRequestBodyBytes);');
  }
  if (hasBody && hasMultipart) {
    buffer.writeln(
      '      final jsonBody = '
      'Map<String, dynamic>.from(multipart.fields);',
    );
  } else if (hasBody) {
    buffer
      ..writeln('      final requestBody = await _r.readBodyLimited(')
      ..writeln('          ctx.request, ctx.registry.maxRequestBodyBytes);')
      ..writeln('      final jsonBody = requestBody.isNotEmpty')
      ..writeln('          ? _r.decodeBody(ctx.request, requestBody)')
      ..writeln('          : const <String, dynamic>{};');
  }
  buffer
    ..writeln('      return await controller().${method.displayName}($args);')
    ..writeln('    },')
    ..write('  ));');
  return buffer.toString();
}
