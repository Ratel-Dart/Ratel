import 'package:analyzer/dart/element/element.dart';

import 'annotation_checkers.dart';
import 'constant_values.dart';
import 'injected_types.dart';
import 'route_path.dart';

String? emitSocketRegistration(MethodElement method, String prefix) {
  final annotation = socketChecker.firstAnnotationOf(method);
  if (annotation == null) return null;

  final path = joinRoutePath(prefix, readString(annotation, 'path') ?? '');
  final args = method.formalParameters.map(_emitArgument).join(', ');

  return "  _r.RatelHandler.registerSocket('$path', (socket, ctx) async {\n"
      '    await controller().${method.displayName}($args);\n'
      '  });';
}

String _emitArgument(FormalParameterElement param) {
  if (webSocketChecker.isExactlyType(param.type)) return 'socket';
  if (requestContextChecker.isExactlyType(param.type)) return 'ctx';
  return 'null';
}
