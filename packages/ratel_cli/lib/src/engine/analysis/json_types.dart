import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../model/json_kind.dart';
import 'ratel_annotations.dart';

abstract final class JsonTypes {
  static const _core = {
    'int': JsonKind.integer,
    'double': JsonKind.real,
    'num': JsonKind.number,
    'String': JsonKind.string,
    'bool': JsonKind.boolean,
    'DateTime': JsonKind.dateTime,
    'Uri': JsonKind.uri,
    'BigInt': JsonKind.bigInt,
    'Object': JsonKind.opaque,
    'List': JsonKind.list,
    'Set': JsonKind.set,
    'Iterable': JsonKind.iterable,
    'Map': JsonKind.map,
  };

  static const _passThrough = {
    JsonKind.integer,
    JsonKind.real,
    JsonKind.number,
    JsonKind.string,
    JsonKind.boolean,
    JsonKind.opaque,
  };

  static JsonKind kind(DartType type) {
    if (type is DynamicType || type is InvalidType) return JsonKind.opaque;
    if (type is! InterfaceType) return JsonKind.unsupported;
    final element = type.element;
    if (element is EnumElement) return JsonKind.enumeration;
    final library = element.library.uri;
    if (library.toString() == 'dart:core') {
      final kind = _core[element.name] ?? JsonKind.unsupported;
      if (kind == JsonKind.map && !_hasStringKeys(type)) {
        return JsonKind.unsupported;
      }
      return kind;
    }
    if (library.isScheme('dart') || RatelAnnotations.isRatelLibrary(library)) {
      return JsonKind.unsupported;
    }
    return element is ClassElement ? JsonKind.dto : JsonKind.unsupported;
  }

  static bool isCollection(JsonKind kind) =>
      kind == JsonKind.list ||
      kind == JsonKind.set ||
      kind == JsonKind.iterable;

  static bool passesThrough(DartType type) {
    final kind = JsonTypes.kind(type);
    if (_passThrough.contains(kind)) return true;
    if (kind == JsonKind.list) return passesThrough(elementOf(type));
    if (kind == JsonKind.map) return passesThrough(valueOf(type));
    return false;
  }

  static bool isNullable(DartType type) =>
      type is DynamicType ||
      type.nullabilitySuffix == NullabilitySuffix.question;

  static DartType elementOf(DartType type) =>
      (type as InterfaceType).typeArguments.first;

  static DartType valueOf(DartType type) =>
      (type as InterfaceType).typeArguments.last;

  static InterfaceType nonNullable(InterfaceType type) =>
      type.element.instantiate(
        typeArguments: type.typeArguments,
        nullabilitySuffix: NullabilitySuffix.none,
      );

  static List<InterfaceType>? dtosIn(DartType type) {
    final found = <InterfaceType>[];
    return _collect(type, found) ? found : null;
  }

  static bool isPublic(DartType type) {
    final alias = type.alias;
    if (alias != null &&
        (_isPrivate(alias.element.name) ||
            !alias.typeArguments.every(isPublic))) {
      return false;
    }
    if (type is InterfaceType) {
      return !_isPrivate(type.element.name) &&
          type.typeArguments.every(isPublic);
    }
    return true;
  }

  static String key(DartType type) {
    if (type is! InterfaceType) return type.getDisplayString();
    final element = type.element;
    final arguments = type.typeArguments.isEmpty
        ? ''
        : '<${type.typeArguments.map(key).join(', ')}>';
    final suffix = isNullable(type) ? '?' : '';
    return '${element.library.uri}#${element.name}$arguments$suffix';
  }

  static int depth(DartType type) {
    if (type is! InterfaceType) return 1;
    var deepest = 0;
    for (final argument in type.typeArguments) {
      final nested = depth(argument);
      if (nested > deepest) deepest = nested;
    }
    return deepest + 1;
  }

  static List<String> words(DartType type) => switch (type) {
        InterfaceType() => [
            type.element.name ?? '',
            for (final argument in type.typeArguments) ...words(argument),
          ],
        DynamicType() => ['Dynamic'],
        _ => const [],
      };

  static bool _collect(DartType type, List<InterfaceType> found) {
    final kind = JsonTypes.kind(type);
    if (kind == JsonKind.unsupported) return false;
    if (isCollection(kind)) return _collect(elementOf(type), found);
    if (kind == JsonKind.map) return _collect(valueOf(type), found);
    if (kind == JsonKind.dto) found.add(nonNullable(type as InterfaceType));
    return true;
  }

  static bool _hasStringKeys(InterfaceType type) {
    final key = type.typeArguments.first;
    return key is InterfaceType &&
        key.isDartCoreString &&
        key.nullabilitySuffix == NullabilitySuffix.none;
  }

  static bool _isPrivate(String? name) => name == null || name.startsWith('_');
}
