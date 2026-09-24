import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';

import '../model/parameter_source.dart';
import '../model/scanned_parameter.dart';
import 'constant_values.dart';
import 'ratel_annotations.dart';

abstract final class ParameterScanner {
  static List<ScannedParameter> route(MethodElement method) =>
      [for (final parameter in method.formalParameters) _route(parameter)];

  static List<ScannedParameter> socket(MethodElement method) =>
      [for (final parameter in method.formalParameters) _socket(parameter)];

  static ScannedParameter _route(FormalParameterElement parameter) {
    final type = parameter.type;
    final name = parameter.name ?? '';
    if (RatelAnnotations.isRatelType(type, 'RequestContext')) {
      return _of(parameter, ParameterSource.context, name);
    }
    if (RatelAnnotations.isRatelType(type, 'MultipartData')) {
      return _of(parameter, ParameterSource.multipart, name);
    }
    if (RatelAnnotations.has(parameter, 'Body')) {
      return _of(parameter, ParameterSource.body, name, isRequired: true);
    }
    final path = RatelAnnotations.first(parameter, 'PathParam');
    if (path != null) {
      return _of(
        parameter,
        ParameterSource.path,
        ConstantValues.string(path, 'name') ?? name,
        isRequired: true,
      );
    }
    if (RatelAnnotations.has(parameter, 'Param')) {
      return _of(parameter, ParameterSource.query, name);
    }
    final header = RatelAnnotations.first(parameter, 'Header');
    if (header != null) {
      return _of(
        parameter,
        ParameterSource.header,
        ConstantValues.string(header, 'name') ?? name,
      );
    }
    final cookie = RatelAnnotations.first(parameter, 'CookieParam');
    if (cookie != null) {
      return _of(
        parameter,
        ParameterSource.cookie,
        ConstantValues.string(cookie, 'name') ?? name,
      );
    }
    return _of(parameter, ParameterSource.unbound, name);
  }

  static ScannedParameter _socket(FormalParameterElement parameter) {
    final type = parameter.type;
    final name = parameter.name ?? '';
    if (RatelAnnotations.isWebSocket(type)) {
      return _of(parameter, ParameterSource.webSocket, name);
    }
    if (RatelAnnotations.isRatelType(type, 'RequestContext')) {
      return _of(parameter, ParameterSource.context, name);
    }
    return _of(parameter, ParameterSource.unbound, name);
  }

  static ScannedParameter _of(
    FormalParameterElement parameter,
    ParameterSource source,
    String bindingName, {
    bool? isRequired,
  }) =>
      ScannedParameter(
        element: parameter,
        dartName: parameter.name ?? '',
        isNamed: parameter.isNamed,
        source: source,
        bindingName: bindingName,
        type: parameter.type,
        isRequired: isRequired ??
            parameter.type.nullabilitySuffix != NullabilitySuffix.question,
      );
}
