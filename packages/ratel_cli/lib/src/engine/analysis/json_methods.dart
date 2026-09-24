import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'ratel_annotations.dart';

abstract final class JsonMethods {
  static bool hasToJson(InterfaceType type) {
    final method = type.lookUpMethod('toJson', type.element.library);
    if (method == null || method.isStatic || method.isPrivate) return false;
    if (method.returnType is VoidType) return false;
    final library = method.library.uri;
    if (library.isScheme('dart') || RatelAnnotations.isRatelLibrary(library)) {
      return false;
    }
    return method.formalParameters.every((parameter) => parameter.isOptional);
  }

  static bool hasFromJson(InterfaceType type) {
    final element = type.element;
    final constructor = type.constructors
        .where((constructor) =>
            constructor.name == 'fromJson' && constructor.isPublic)
        .firstOrNull;
    if (constructor == null) return false;
    if (element is ClassElement &&
        (element.isAbstract || element.isSealed) &&
        !constructor.isFactory) {
      return false;
    }
    final parameters = constructor.formalParameters;
    if (parameters.isEmpty || !parameters.first.isPositional) return false;
    if (parameters.skip(1).any((parameter) => parameter.isRequired)) {
      return false;
    }
    final library = element.library;
    final provider = library.typeProvider;
    final json = provider.mapType(
      provider.stringType,
      provider.objectQuestionType,
    );
    return library.typeSystem.isSubtypeOf(json, parameters.first.type);
  }
}
