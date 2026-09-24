import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../model/column_kind.dart';

abstract final class ColumnTypes {
  static const supported = 'int, double, num, String, bool, DateTime, '
      'Uint8List, List<int> or an enum, each possibly nullable';

  static const _core = {
    'int': ColumnKind.integer,
    'double': ColumnKind.real,
    'num': ColumnKind.number,
    'String': ColumnKind.text,
    'bool': ColumnKind.boolean,
    'DateTime': ColumnKind.dateTime,
  };

  static ColumnKind kind(DartType type) {
    if (type is! InterfaceType) return ColumnKind.unsupported;
    final element = type.element;
    if (element is EnumElement) return ColumnKind.enumeration;
    final library = element.library.uri.toString();
    if (library == 'dart:typed_data' && element.name == 'Uint8List') {
      return ColumnKind.bytes;
    }
    if (library != 'dart:core') return ColumnKind.unsupported;
    if (type.isDartCoreList && _isInt(type.typeArguments.first)) {
      return ColumnKind.bytes;
    }
    return _core[element.name] ?? ColumnKind.unsupported;
  }

  static bool isUnresolved(DartType type) =>
      type is InvalidType ||
      (type is InterfaceType && type.typeArguments.any(isUnresolved));

  static bool isNullable(DartType type) =>
      type.nullabilitySuffix == NullabilitySuffix.question;

  static bool _isInt(DartType type) => type.isDartCoreInt && !isNullable(type);
}
