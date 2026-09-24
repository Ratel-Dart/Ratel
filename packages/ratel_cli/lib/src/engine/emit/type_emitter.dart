import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'import_allocator.dart';

final class TypeEmitter {
  TypeEmitter(this._imports);

  final ImportAllocator _imports;

  String emit(DartType type) => '${nonNullable(type)}${_suffix(type)}';

  String nonNullable(DartType type) {
    final alias = type.alias;
    if (alias != null) {
      return '${_qualified(alias.element.library.uri, alias.element.name ?? '')}'
          '${_arguments(alias.typeArguments)}';
    }
    return switch (type) {
      InterfaceType() =>
        '${_qualified(type.element.library.uri, type.element.name ?? '')}'
            '${_arguments(type.typeArguments)}',
      RecordType() => _record(type),
      FunctionType() => _function(type),
      VoidType() => 'void',
      NeverType() => 'Never',
      _ => 'dynamic',
    };
  }

  String _suffix(DartType type) {
    if (type is DynamicType || type is VoidType) return '';
    if (type.alias == null &&
        type is! InterfaceType &&
        type is! RecordType &&
        type is! FunctionType &&
        type is! NeverType) {
      return '';
    }
    return type.nullabilitySuffix == NullabilitySuffix.question ? '?' : '';
  }

  String _qualified(Uri library, String name) {
    final prefix = _imports.prefixFor(library);
    return prefix == null ? name : '$prefix.$name';
  }

  String _arguments(List<DartType> arguments) =>
      arguments.isEmpty ? '' : '<${arguments.map(emit).join(', ')}>';

  String _record(RecordType type) {
    final positional = [
      for (final field in type.positionalFields) emit(field.type)
    ];
    final named = [
      for (final field in type.namedFields) '${emit(field.type)} ${field.name}',
    ];
    if (named.isEmpty) {
      return positional.length == 1
          ? '(${positional.single},)'
          : '(${positional.join(', ')})';
    }
    return '(${[...positional, '{${named.join(', ')}}'].join(', ')})';
  }

  String _function(FunctionType type) {
    final required = <String>[];
    final optional = <String>[];
    final named = <String>[];
    for (final parameter in type.formalParameters) {
      final parameterType = emit(parameter.type);
      if (parameter.isNamed) {
        final modifier = parameter.isRequiredNamed ? 'required ' : '';
        named.add('$modifier$parameterType ${parameter.name}');
      } else if (parameter.isOptionalPositional) {
        optional.add(parameterType);
      } else {
        required.add(parameterType);
      }
    }
    final parts = [
      ...required,
      if (optional.isNotEmpty) '[${optional.join(', ')}]',
      if (named.isNotEmpty) '{${named.join(', ')}}',
    ];
    return '${emit(type.returnType)} Function(${parts.join(', ')})';
  }
}
