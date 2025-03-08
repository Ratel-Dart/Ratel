import 'dart:convert';
import 'dart:mirrors';

import '../annotations/geral_annotations.dart';

abstract class RatelHandler {
  static final List<Route> routesList = [];

  RatelHandler() {
    registerRoutes();
  }

  void registerRoutes() {
    InstanceMirror instancia = reflect(this);
    ClassMirror classeMirror = instancia.type;

    for (var method in classeMirror.declarations.values) {
      if (method is MethodMirror && method.isRegularMethod) {
        for (var metadata in method.metadata) {
          if (metadata.reflectee is Get) {
            var route = metadata.reflectee as Get;
            routesList.add(router_add(route.path, "GET", instancia, method));
          }
          if (metadata.reflectee is Post) {
            var route = metadata.reflectee as Post;
            routesList.add(router_add(route.path, "POST", instancia, method));
          }
          if (metadata.reflectee is Put) {
            var route = metadata.reflectee as Put;
            routesList.add(router_add(route.path, "PUT", instancia, method));
          }
          if (metadata.reflectee is Delete) {
            var route = metadata.reflectee as Delete;
            routesList.add(router_add(route.path, "DELETE", instancia, method));
          }
        }
      }
    }
  }

  Route router_add(String path, String typeMethod, InstanceMirror instancia,
      MethodMirror method) {
    return Route(
      path: path,
      method: typeMethod,
      handler: ([dynamic request]) async {
        List<dynamic> argumentos = [];
        String methodType = typeMethod.toUpperCase();

        if (methodType == "GET") {
          for (var param in method.parameters) {
            if (param.metadata.any((meta) => meta.reflectee is Param)) {
              String paramName = MirrorSystem.getName(param.simpleName);
              if (request.uri.queryParameters.containsKey(paramName)) {
                String valueStr = request.uri.queryParameters[paramName]!;
                Type paramType = param.type.reflectedType;
                if (paramType == int) {
                  argumentos.add(int.parse(valueStr));
                } else if (paramType == double) {
                  argumentos.add(double.parse(valueStr));
                } else if (paramType == bool) {
                  argumentos.add(valueStr.toLowerCase() == "true");
                } else {
                  argumentos.add(valueStr);
                }
              } else {
                argumentos.add(null);
              }
            } else {
              argumentos.add(null);
            }
          }
        } else if (methodType == "POST" ||
            methodType == "PUT" ||
            methodType == "DELETE") {
          String bodyString = await utf8.decoder.bind(request).join();
          if (bodyString.isNotEmpty) {
            Map<String, dynamic> jsonMap = jsonDecode(bodyString);
            for (var param in method.parameters) {
              bool isBody =
                  param.metadata.any((meta) => meta.reflectee is Body);
              if (isBody) {
                Type paramType = param.type.reflectedType;
                ClassMirror typeMirror = reflectClass(paramType);
                bool hasJsonAnnotation =
                    typeMirror.metadata.any((m) => m.reflectee is Json);
                if (hasJsonAnnotation) {
                  var instance = _generateFromJson(typeMirror, jsonMap);
                  argumentos.add(instance);
                } else {
                  argumentos.add(null);
                }
              } else if (param.metadata
                  .any((meta) => meta.reflectee is Param)) {
                String paramName = MirrorSystem.getName(param.simpleName);
                if (request.uri.queryParameters.containsKey(paramName)) {
                  String valueStr = request.uri.queryParameters[paramName]!;
                  Type paramType = param.type.reflectedType;
                  if (paramType == int) {
                    argumentos.add(int.parse(valueStr));
                  } else if (paramType == double) {
                    argumentos.add(double.parse(valueStr));
                  } else if (paramType == bool) {
                    argumentos.add(valueStr.toLowerCase() == "true");
                  } else {
                    argumentos.add(valueStr);
                  }
                } else {
                  argumentos.add(null);
                }
              } else {
                argumentos.add(null);
              }
            }
          } else {
            for (var param in method.parameters) {
              if (param.metadata.any((meta) => meta.reflectee is Param)) {
                String paramName = MirrorSystem.getName(param.simpleName);
                if (request.uri.queryParameters.containsKey(paramName)) {
                  String valueStr = request.uri.queryParameters[paramName]!;
                  Type paramType = param.type.reflectedType;
                  if (paramType == int) {
                    argumentos.add(int.parse(valueStr));
                  } else if (paramType == double) {
                    argumentos.add(double.parse(valueStr));
                  } else if (paramType == bool) {
                    argumentos.add(valueStr.toLowerCase() == "true");
                  } else {
                    argumentos.add(valueStr);
                  }
                } else {
                  argumentos.add(null);
                }
              } else {
                argumentos.add(null);
              }
            }
          }
        } else {
          argumentos = [];
        }

        return await instancia.invoke(method.simpleName, argumentos).reflectee;
      },
    );
  }

  dynamic _generateFromJson(
      ClassMirror typeMirror, Map<String, dynamic> jsonMap) {
    var instance = typeMirror.newInstance(Symbol(''), []);

    for (var field in typeMirror.declarations.values) {
      if (field is VariableMirror && !field.isStatic) {
        String fieldName = MirrorSystem.getName(field.simpleName);
        if (jsonMap.containsKey(fieldName)) {
          instance.setField(field.simpleName, jsonMap[fieldName]);
        }
      }
    }

    return instance.reflectee;
  }

  static List<Route> get routes => routesList;
}
