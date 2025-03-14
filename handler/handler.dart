import 'dart:convert';
import 'dart:mirrors';

import '../annotations/geral_annotations.dart';

abstract class RatelHandler {
  static final List<Route> routesList = [];

  RatelHandler() {
    _registerRoutes();
  }

  void _registerRoutes() {
    InstanceMirror instance = reflect(this);
    ClassMirror classMirror = instance.type;

    bool classProtected =
        classMirror.metadata.any((m) => m.reflectee is Protected);

    for (var declaration in classMirror.declarations.values) {
      if (declaration is MethodMirror && declaration.isRegularMethod) {
        bool methodPublic =
            declaration.metadata.any((m) => m.reflectee is Public);
        bool methodProtected =
            declaration.metadata.any((m) => m.reflectee is Protected);
        bool isProtected = (classProtected && !methodPublic) || methodProtected;
        for (var metadata in declaration.metadata) {
          String? httpMethod;
          String? path;
          var reflectee = metadata.reflectee;
          if (reflectee is Get) {
            httpMethod = "GET";
            path = reflectee.path;
          } else if (reflectee is Post) {
            httpMethod = "POST";
            path = reflectee.path;
          } else if (reflectee is Put) {
            httpMethod = "PUT";
            path = reflectee.path;
          } else if (reflectee is Delete) {
            httpMethod = "DELETE";
            path = reflectee.path;
          }
          if (httpMethod != null && path != null) {
            routes.add(_routerAdd(
                path, httpMethod, instance, declaration, isProtected));
          }
        }
      }
    }
  }

  Route _routerAdd(String path, String methodType, InstanceMirror instance,
      MethodMirror method, bool isProtected) {
    return Route(
      path: path,
      method: methodType,
      isProtected: isProtected,
      methodMirror: method,
      handler: ([dynamic request]) async {
        List<dynamic> args = [];
        String mType = methodType.toUpperCase();
        if (mType == "GET") {
          for (var param in method.parameters) {
            if (param.metadata.any((meta) => meta.reflectee is Param)) {
              String paramName = MirrorSystem.getName(param.simpleName);
              if (request.uri.queryParameters.containsKey(paramName)) {
                String valueStr = request.uri.queryParameters[paramName]!;
                Type paramType = param.type.reflectedType;
                if (paramType == int) {
                  args.add(int.parse(valueStr));
                } else if (paramType == double) {
                  args.add(double.parse(valueStr));
                } else if (paramType == bool) {
                  args.add(valueStr.toLowerCase() == "true");
                } else {
                  args.add(valueStr);
                }
              } else {
                args.add(null);
              }
            } else {
              args.add(null);
            }
          }
        } else if (mType == "POST" || mType == "PUT" || mType == "DELETE") {
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
                  var obj = _generateFromJson(typeMirror, jsonMap);
                  args.add(obj);
                } else {
                  args.add(null);
                }
              } else if (param.metadata
                  .any((meta) => meta.reflectee is Param)) {
                String paramName = MirrorSystem.getName(param.simpleName);
                if (request.uri.queryParameters.containsKey(paramName)) {
                  String valueStr = request.uri.queryParameters[paramName]!;
                  Type paramType = param.type.reflectedType;
                  if (paramType == int) {
                    args.add(int.parse(valueStr));
                  } else if (paramType == double) {
                    args.add(double.parse(valueStr));
                  } else if (paramType == bool) {
                    args.add(valueStr.toLowerCase() == "true");
                  } else {
                    args.add(valueStr);
                  }
                } else {
                  args.add(null);
                }
              } else {
                args.add(null);
              }
            }
          } else {
            args.addAll(List.filled(method.parameters.length, null));
          }
        } else {
          args = [];
        }
        return await instance.invoke(method.simpleName, args).reflectee;
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
