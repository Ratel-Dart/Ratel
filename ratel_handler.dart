import 'dart:mirrors';

import 'ratel_methods.dart';
import 'ratel_route.dart';

abstract class RatelHandler {
  static final List<Route> _routes = [];

  RatelHandler() {
    registerRoutes();
  }

  void registerRoutes() {
    var instancia = reflect(this);
    var classeMirror = instancia.type;

    for (var method in classeMirror.declarations.values) {
      if (method is MethodMirror) {
        for (var metadata in method.metadata) {
          if (metadata.reflectee is Get) {
            var route = metadata.reflectee as Get;
            _routes.add(Route(
              path: route.path,
              method: "GET",
              handler: () => instancia.invoke(method.simpleName, []).reflectee,
            ));
          }
          if (metadata.reflectee is Post) {
            var path = metadata.reflectee as Post;
            _routes.add(Route(
              path: path.path,
              method: "POST",
              handler: () => instancia.invoke(method.simpleName, []).reflectee,
            ));
          }
        }
      }
    }
  }

  static List<Route> get routes => _routes;
}
