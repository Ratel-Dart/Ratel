import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

import '../diagnostics/diagnostic_codes.dart';
import '../diagnostics/element_diagnostics.dart';
import '../diagnostics/ratel_diagnostic.dart';
import '../emit/route_path.dart';
import '../model/scanned_controller.dart';
import '../model/scanned_route.dart';
import '../model/scanned_socket.dart';
import 'constant_values.dart';
import 'element_queries.dart';
import 'parameter_scanner.dart';
import 'ratel_annotations.dart';
import 'route_parameter_checks.dart';

abstract final class ControllerScanner {
  static List<ScannedController> scan(
    LibraryElement library,
    List<RatelDiagnostic> diagnostics,
  ) {
    final controllers = <ScannedController>[];
    for (final element in library.classes) {
      final annotation = RatelAnnotations.first(element, 'Controller');
      if (annotation == null) {
        _reportOrphanRoutes(element, diagnostics);
        continue;
      }
      if (!_isValid(element, diagnostics)) continue;
      controllers.add(_controller(element, annotation, diagnostics));
    }
    return controllers;
  }

  static void _reportOrphanRoutes(
    ClassElement element,
    List<RatelDiagnostic> diagnostics,
  ) {
    final extendsHandler = element.allSupertypes
        .any((type) => RatelAnnotations.isRatelType(type, 'RatelHandler'));
    final hint = extendsHandler
        ? ' RatelHandler is no longer needed: remove `extends RatelHandler`.'
        : '';
    for (final method in element.methods) {
      if (!RatelAnnotations.hasRoute(method)) continue;
      diagnostics.add(ElementDiagnostics.at(
        method,
        DiagnosticCodes.missingController,
        '${element.name}.${method.name} is annotated as a route but '
        '${element.name} has no @Controller annotation; add @Controller() to '
        'serve it.$hint',
      ));
    }
  }

  static bool _isValid(
    ClassElement element,
    List<RatelDiagnostic> diagnostics,
  ) {
    final name = element.name ?? '';
    if (element.isPrivate) {
      diagnostics.add(ElementDiagnostics.at(
        element,
        DiagnosticCodes.privateClass,
        'The controller $name must be public: the generated route table lives '
        'in another library. Rename it without the leading underscore.',
      ));
      return false;
    }
    if (element.isAbstract) {
      diagnostics.add(ElementDiagnostics.at(
        element,
        DiagnosticCodes.abstractController,
        'The controller $name is abstract, so Ratel cannot create it. Put '
        '@Controller on a concrete class.',
      ));
      return false;
    }
    if (element.typeParameters.isNotEmpty) {
      diagnostics.add(ElementDiagnostics.at(
        element,
        DiagnosticCodes.genericController,
        'The controller $name is generic, so Ratel cannot create it. Put '
        '@Controller on a class without type parameters.',
      ));
      return false;
    }
    return true;
  }

  static ScannedController _controller(
    ClassElement element,
    DartObject annotation,
    List<RatelDiagnostic> diagnostics,
  ) {
    final prefix = ConstantValues.string(annotation, 'prefix') ?? '';
    final classProtected = RatelAnnotations.first(element, 'Protected');
    final routes = <ScannedRoute>[];
    final sockets = <ScannedSocket>[];
    for (final method in element.methods) {
      if (!RatelAnnotations.hasRoute(method)) continue;
      if (method.isStatic) {
        diagnostics.add(ElementDiagnostics.at(
          method,
          DiagnosticCodes.staticRoute,
          'The route method ${element.name}.${method.name} is static, but '
          'Ratel calls routes on a controller instance. Remove the static '
          'modifier.',
        ));
        continue;
      }
      if (method.isPrivate) {
        diagnostics.add(ElementDiagnostics.at(
          method,
          DiagnosticCodes.privateRouteMethod,
          'The route method ${element.name}.${method.name} must be public: '
          'the generated route table lives in another library.',
        ));
        continue;
      }
      final methodRoutes = _routes(method, prefix, classProtected);
      RouteParameterChecks.check(element, methodRoutes, diagnostics);
      routes.addAll(methodRoutes);
      final socket = RatelAnnotations.first(method, 'Socket');
      if (socket != null) {
        sockets.add(ScannedSocket(
          methodName: method.name ?? '',
          path: RoutePath.join(
            prefix,
            ConstantValues.string(socket, 'path') ?? '',
          ),
          parameters: ParameterScanner.socket(method),
        ));
      }
    }
    return ScannedController(
      element: element,
      isConstructible: ElementQueries.canConstruct(element),
      routes: routes,
      sockets: sockets,
    );
  }

  static List<ScannedRoute> _routes(
    MethodElement method,
    String prefix,
    DartObject? classProtected,
  ) {
    final routes = <ScannedRoute>[];
    for (final MapEntry(key: annotationName, value: verb)
        in RatelAnnotations.verbs.entries) {
      final route = RatelAnnotations.first(method, annotationName);
      if (route == null) continue;
      final methodProtected = RatelAnnotations.first(method, 'Protected');
      final isPublic = RatelAnnotations.has(method, 'Public');
      final effective = methodProtected ?? (isPublic ? null : classProtected);
      routes.add(ScannedRoute(
        methodName: method.name ?? '',
        verb: verb,
        path:
            RoutePath.join(prefix, ConstantValues.string(route, 'path') ?? ''),
        isProtected: effective != null,
        roles: ConstantValues.strings(effective, 'roles'),
        parameters: ParameterScanner.route(method),
      ));
    }
    return routes;
  }
}
