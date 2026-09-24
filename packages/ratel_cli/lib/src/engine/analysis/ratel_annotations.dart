import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

abstract final class RatelAnnotations {
  static const verbs = {
    'Get': 'GET',
    'Post': 'POST',
    'Put': 'PUT',
    'Delete': 'DELETE',
    'Patch': 'PATCH',
    'Head': 'HEAD',
    'Options': 'OPTIONS',
  };

  static DartObject? first(Element element, String name) {
    for (final annotation in element.metadata.annotations) {
      final value = annotation.computeConstantValue();
      final type = value?.type;
      if (type != null && isRatelType(type, name)) return value;
    }
    return null;
  }

  static bool has(Element element, String name) => first(element, name) != null;

  static bool isRatelType(DartType type, String name) {
    if (type is! InterfaceType) return false;
    final element = type.element;
    return element.name == name && isRatelLibrary(element.library.uri);
  }

  static bool isRatelLibrary(Uri uri) =>
      uri.isScheme('package') &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == 'ratel';

  static bool isWebSocket(DartType type) {
    if (type is! InterfaceType) return false;
    final element = type.element;
    final library = element.library.uri.toString();
    return element.name == 'WebSocket' &&
        (library == 'dart:io' || library == 'dart:_http');
  }

  static bool hasRoute(MethodElement method) =>
      verbs.keys.any((verb) => has(method, verb)) || has(method, 'Socket');
}
