import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../analysis/json_types.dart';
import 'dart_literal.dart';

abstract final class ConstantEmitter {
  static bool canEmit(DartObject value) => emit(value, (_) => '') != null;

  static String? emit(DartObject value, String Function(DartType type) name) =>
      _emit(value, name, isConst: true);

  static String? _emit(
    DartObject value,
    String Function(DartType type) name, {
    required bool isConst,
  }) {
    if (value.isNull) return 'null';
    final type = value.type;
    if (type is! InterfaceType || !JsonTypes.isPublic(type)) return null;
    final keyword = isConst ? 'const ' : '';
    if (type.isDartCoreBool) return value.toBoolValue()?.toString();
    if (type.isDartCoreInt) return value.toIntValue()?.toString();
    if (type.isDartCoreDouble) return _double(value.toDoubleValue());
    if (type.isDartCoreString) {
      final text = value.toStringValue();
      return text == null ? null : DartLiteral.string(text);
    }
    final element = type.element;
    if (element is EnumElement) {
      final index = value.getField('index')?.toIntValue();
      final constants = element.constants;
      if (index == null || index < 0 || index >= constants.length) return null;
      return '${name(type)}.${constants[index].name}';
    }
    if (type.isDartCoreList || type.isDartCoreSet) {
      final items = type.isDartCoreList
          ? value.toListValue()
          : value.toSetValue()?.toList();
      final emitted = _all(items, name);
      if (emitted == null) return null;
      final open = type.isDartCoreList ? '[' : '{';
      final close = type.isDartCoreList ? ']' : '}';
      return '$keyword<${name(type.typeArguments.first)}>'
          '$open${emitted.join(', ')}$close';
    }
    if (type.isDartCoreMap) {
      final entries = value.toMapValue();
      if (entries == null) return null;
      final emitted = <String>[];
      for (final MapEntry(:key, :value) in entries.entries) {
        if (key == null || value == null) return null;
        final k = _emit(key, name, isConst: false);
        final v = _emit(value, name, isConst: false);
        if (k == null || v == null) return null;
        emitted.add('$k: $v');
      }
      return '$keyword<${name(type.typeArguments.first)}, '
          '${name(type.typeArguments.last)}>{${emitted.join(', ')}}';
    }
    return null;
  }

  static List<String>? _all(
    List<DartObject>? items,
    String Function(DartType type) name,
  ) {
    if (items == null) return null;
    final emitted = <String>[];
    for (final item in items) {
      final text = _emit(item, name, isConst: false);
      if (text == null) return null;
      emitted.add(text);
    }
    return emitted;
  }

  static String? _double(double? value) {
    if (value == null) return null;
    if (value.isNaN) return 'double.nan';
    if (value == double.infinity) return 'double.infinity';
    if (value == double.negativeInfinity) return 'double.negativeInfinity';
    return value.toString();
  }
}
