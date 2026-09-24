import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../diagnostics/diagnostic_codes.dart';
import '../diagnostics/element_diagnostics.dart';
import '../diagnostics/ratel_diagnostic.dart';
import '../emit/constant_emitter.dart';
import '../model/construction_plan.dart';
import '../model/constructor_argument.dart';
import '../model/json_kind.dart';
import '../model/parameter_source.dart';
import '../model/scanned_controller.dart';
import '../model/scanned_dto.dart';
import '../model/scanned_field.dart';
import '../model/scanned_parameter.dart';
import '../model/scanned_route.dart';
import 'construction_planner.dart';
import 'element_queries.dart';
import 'json_methods.dart';
import 'json_types.dart';
import 'ratel_annotations.dart';

final class DtoCollector {
  DtoCollector._(this._diagnostics);

  final List<RatelDiagnostic> _diagnostics;
  final Set<String> _reported = {};
  final Set<String> _owners = {};
  final Map<String, InterfaceType> _types = {};
  final Map<String, List<ScannedField>> _properties = {};
  final Set<String> _encoded = {};
  final Set<String> _sketched = {};
  final Set<String> _decoded = {};
  final Map<String, ConstructionPlan> _plans = {};

  static const _maxDepth = 12;

  static const _supported = 'Use a class, an enum, String, int, double, num, '
      'bool, DateTime, Uri, BigInt, or a List, Set or Map<String, ...> of '
      'those.';

  static List<ScannedDto> collect(
    List<ScannedController> controllers,
    List<RatelDiagnostic> diagnostics,
  ) {
    final collector = DtoCollector._(diagnostics);
    for (final controller in controllers) {
      for (final route in controller.routes) {
        collector._route(controller, route);
      }
    }
    return collector._dtos();
  }

  void _route(ScannedController controller, ScannedRoute route) {
    final owner = '${controller.element.name}.${route.methodName}';
    if (!_owners.add('${controller.element.library.uri} $owner')) return;
    for (final parameter in route.parameters) {
      if (parameter.source == ParameterSource.body) _body(parameter, owner);
    }
    final method = controller.element.getMethod(route.methodName);
    final payload = _payload(route.returnType);
    if (method == null || payload == null) return;
    final path = [owner];
    if (_accepts(payload, path, method, decoding: false)) {
      _encode(payload, path, strict: true);
    }
  }

  void _body(ScannedParameter parameter, String owner) {
    final type = parameter.type;
    if (type is InvalidType) return;
    if (type is! InterfaceType || JsonTypes.kind(type) != JsonKind.dto) {
      _report(
        parameter.element,
        DiagnosticCodes.bodyNotClass,
        'The @Body() parameter ${parameter.dartName} of $owner has type '
        '${type.getDisplayString()}, but Ratel decodes a body only into a '
        'class of your own. Declare a class whose fields match the JSON '
        'object and use it as the parameter type.',
      );
      return;
    }
    final dto = JsonTypes.nonNullable(type);
    final path = [owner];
    if (_accepts(dto, path, parameter.element, decoding: true)) {
      _decode(dto, path);
    }
  }

  static InterfaceType? _payload(DartType type) {
    DartType current = type;
    while (true) {
      if (current is! InterfaceType) return null;
      final unwrapped = _unwrap(current);
      if (unwrapped != null) {
        current = unwrapped;
        continue;
      }
      final kind = JsonTypes.kind(current);
      if (JsonTypes.isCollection(kind)) {
        current = JsonTypes.elementOf(current);
      } else if (kind == JsonKind.map) {
        current = JsonTypes.valueOf(current);
      } else if (kind == JsonKind.dto) {
        return JsonTypes.nonNullable(current);
      } else {
        return null;
      }
    }
  }

  static DartType? _unwrap(InterfaceType type) {
    final element = type.element;
    if (element.library.uri.toString() == 'dart:async' &&
        (element.name == 'Future' || element.name == 'FutureOr')) {
      return type.typeArguments.first;
    }
    for (final candidate in [type, ...type.allSupertypes]) {
      if (RatelAnnotations.isRatelType(candidate, 'Response')) {
        return candidate.typeArguments.first;
      }
    }
    return null;
  }

  void _encode(
    InterfaceType type,
    List<String> path, {
    required bool strict,
  }) {
    final key = JsonTypes.key(type);
    _types.putIfAbsent(key, () => type);
    if (strict) {
      if (!_encoded.add(key)) return;
    } else if (_encoded.contains(key) || !_sketched.add(key)) {
      return;
    }
    if (JsonMethods.hasToJson(type)) return;
    final owner = type.element.name;
    for (final property in _propertiesOf(key, type)) {
      final at = [...path, '$owner.${property.name}'];
      if (strict) {
        _follow(
          property.type,
          at,
          property.element,
          '$key.${property.name}',
          (dto) => _encode(dto, at, strict: true),
          decoding: false,
        );
      } else if (_encodable(property.type)) {
        for (final dto in JsonTypes.dtosIn(property.type) ?? const []) {
          _encode(dto, at, strict: false);
        }
      }
    }
  }

  void _decode(InterfaceType type, List<String> path) {
    final key = JsonTypes.key(type);
    _types.putIfAbsent(key, () => type);
    if (!_decoded.add(key)) return;
    _encode(type, path, strict: false);
    if (JsonMethods.hasFromJson(type)) return;
    final name = type.getDisplayString();
    final (:plan, :problem) = ConstructionPlanner.plan(type);
    if (plan == null) {
      _report(
        type.element,
        DiagnosticCodes.dtoNotConstructible,
        '${path.join(' -> ')} needs Ratel to build $name from JSON, but '
        '$problem. Give $name a public unnamed constructor whose parameters '
        'are its fields.',
      );
      return;
    }
    var valid = true;
    for (final argument in plan.arguments) {
      final problem = _defaultProblem(argument);
      if (problem == null) continue;
      valid = false;
      _report(
        argument.element,
        DiagnosticCodes.dtoNotConstructible,
        '${path.join(' -> ')} needs Ratel to build $name from JSON, but '
        '$problem.',
      );
    }
    if (!valid) return;
    _plans[key] = plan;
    final owner = type.element.name;
    for (final argument in plan.arguments) {
      final property = argument.property;
      if (property == null) continue;
      final at = [...path, '$owner.$property'];
      _follow(
        argument.type,
        at,
        _anchor(argument.element),
        '$key.$property',
        (dto) => _decode(dto, at),
        decoding: true,
      );
    }
    for (final field in plan.assignments) {
      final at = [...path, '$owner.${field.name}'];
      _follow(
        field.type,
        at,
        field.element,
        '$key.${field.name}',
        (dto) => _decode(dto, at),
        decoding: true,
      );
    }
  }

  void _follow(
    DartType type,
    List<String> path,
    Element anchor,
    String subject,
    void Function(InterfaceType dto) visit, {
    required bool decoding,
  }) {
    final dtos = JsonTypes.dtosIn(type);
    final display = type.getDisplayString();
    if (dtos == null) {
      _report(
        anchor,
        DiagnosticCodes.dtoUnsupportedType,
        '${path.join(' -> ')} has type $display, which Ratel cannot convert '
        'to JSON. $_supported',
        subject: subject,
      );
      return;
    }
    if (!JsonTypes.isPublic(type)) {
      _reportPrivate(anchor, path, display, subject);
      return;
    }
    for (final dto in dtos) {
      if (_grows(dto)) {
        _reportGrowth(dto, path, anchor, subject);
      } else if (_accepts(
        dto,
        path,
        anchor,
        decoding: decoding,
        subject: subject,
      )) {
        visit(dto);
      }
    }
  }

  bool _accepts(
    InterfaceType type,
    List<String> path,
    Element anchor, {
    required bool decoding,
    String? subject,
  }) {
    final display = type.getDisplayString();
    if (!JsonTypes.isPublic(type)) {
      _reportPrivate(anchor, path, display, subject);
      return false;
    }
    final modifier = _abstraction(type, decoding: decoding);
    if (modifier == null) return true;
    _report(
      anchor,
      DiagnosticCodes.dtoAbstract,
      '${path.join(' -> ')} uses ${type.element.name}, $modifier, so Ratel '
      'cannot tell which class to convert to and from JSON. Use a concrete '
      'class in its place.',
      subject: subject,
    );
    return false;
  }

  void _reportPrivate(
    Element anchor,
    List<String> path,
    String display,
    String? subject,
  ) {
    _report(
      anchor,
      DiagnosticCodes.privateClass,
      '${path.join(' -> ')} uses the private type $display. Ratel generates '
      'JSON codecs in another library, so the type must be public: rename it '
      'without the leading underscore.',
      subject: subject,
    );
  }

  void _reportGrowth(
    InterfaceType dto,
    List<String> path,
    Element anchor,
    String subject,
  ) {
    final property = path.last;
    final trail = path.sublist(0, path.indexOf(property) + 1).join(' -> ');
    _report(
      anchor,
      DiagnosticCodes.dtoUnsupportedType,
      '$trail nests ${dto.element.name} inside itself with type arguments '
      'that grow at every level, so Ratel would need JSON codecs without '
      'end. Give $property a type whose type arguments do not grow.',
      subject: subject,
    );
  }

  static bool _grows(InterfaceType type) => JsonTypes.depth(type) > _maxDepth;

  static String? _abstraction(InterfaceType type, {required bool decoding}) {
    final element = type.element;
    if (element is! ClassElement) return null;
    if (!element.isSealed && !element.isAbstract) return null;
    final custom =
        decoding ? JsonMethods.hasFromJson(type) : JsonMethods.hasToJson(type);
    if (custom) return null;
    return element.isSealed ? 'a sealed class' : 'an abstract class';
  }

  bool _encodable(DartType type) {
    final dtos = JsonTypes.dtosIn(type);
    return dtos != null &&
        JsonTypes.isPublic(type) &&
        dtos.every(
          (dto) => !_grows(dto) && _abstraction(dto, decoding: false) == null,
        );
  }

  static Element _anchor(FormalParameterElement parameter) =>
      switch (parameter) {
        FieldFormalParameterElement(:final field?) => field,
        _ => parameter,
      };

  static String? _defaultProblem(ConstructorArgument argument) {
    final value = argument.defaultValue;
    final nullable = JsonTypes.isNullable(argument.type);
    final needsDefault = argument.property == null
        ? !nullable || value != null
        : !argument.isRequired && !(nullable && (value?.isNull ?? true));
    if (!needsDefault) return null;
    if (value == null) {
      return 'the optional parameter ${argument.name} has no default value '
          'to use when the JSON lacks it; make the field nullable or required';
    }
    if (ConstantEmitter.canEmit(value)) return null;
    return 'the default value of ${argument.name} cannot be copied into '
        'generated code; make the field nullable or required';
  }

  List<ScannedField> _propertiesOf(String key, InterfaceType type) =>
      _properties.putIfAbsent(key, () => ElementQueries.properties(type));

  void _report(
    Element element,
    String code,
    String message, {
    String? subject,
  }) {
    final diagnostic = ElementDiagnostics.at(_located(element), code, message);
    final identity = subject == null
        ? '$code ${diagnostic.path}:${diagnostic.line}:${diagnostic.column} '
            '$message'
        : '$code $subject';
    if (_reported.add(identity)) _diagnostics.add(diagnostic);
  }

  static Element _located(Element element) {
    final base = element.baseElement;
    if (base is FieldElement) return base.declaringFormalParameter ?? base;
    return base;
  }

  List<ScannedDto> _dtos() => [
        for (final MapEntry(:key, value: type) in _types.entries)
          ScannedDto(
            type: type,
            encodes: _encoded.contains(key),
            decodes: _decoded.contains(key),
            properties: JsonMethods.hasToJson(type)
                ? const []
                : [
                    for (final property in _propertiesOf(key, type))
                      if (_encodable(property.type)) property,
                  ],
            decoding: _plans[key],
            usesToJson: JsonMethods.hasToJson(type),
            usesFromJson:
                _decoded.contains(key) && JsonMethods.hasFromJson(type),
          ),
      ];
}
