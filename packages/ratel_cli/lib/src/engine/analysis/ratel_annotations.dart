import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'package_annotations.dart';

abstract final class RatelAnnotations {
  static const package = 'ratel';

  static const verbs = {
    'Get': 'GET',
    'Post': 'POST',
    'Put': 'PUT',
    'Delete': 'DELETE',
    'Patch': 'PATCH',
    'Head': 'HEAD',
    'Options': 'OPTIONS',
  };

  static DartObject? first(Element element, String name) =>
      PackageAnnotations.first(element, package, name);

  static bool has(Element element, String name) =>
      PackageAnnotations.has(element, package, name);

  static bool isRatelType(DartType type, String name) =>
      PackageAnnotations.isType(type, package, name);

  static bool isRatelLibrary(Uri uri) =>
      PackageAnnotations.isLibrary(uri, package);

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
