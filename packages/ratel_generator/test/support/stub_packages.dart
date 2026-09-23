const stubPackages = <String, String>{
  'ratel|lib/annotations/annotations.dart': _annotations,
  'ratel|lib/http/handler.dart': _handler,
  'ratel_orm|lib/annotations.dart': _ormAnnotations,
  'ratel_orm|lib/ratel_orm.dart': _orm,
};

const _annotations = '''
typedef RouteHandler = Future<dynamic> Function([dynamic request]);

class Route {
  final String path;
  final String method;
  final RouteHandler handler;
  final bool isProtected;
  final List<String> requiredRoles;

  Route({
    required this.path,
    required this.method,
    required this.handler,
    this.isProtected = false,
    this.requiredRoles = const [],
  });
}

class Get {
  final String path;
  const Get(this.path);
}

class Post {
  final String path;
  const Post(this.path);
}

class Put {
  final String path;
  const Put(this.path);
}

class Delete {
  final String path;
  const Delete(this.path);
}

class Patch {
  final String path;
  const Patch(this.path);
}

class Head {
  final String path;
  const Head(this.path);
}

class Options {
  final String path;
  const Options(this.path);
}

class Body {
  const Body();
}

class Json {
  const Json();
}

class Param {
  const Param();
}

class PathParam {
  final String name;
  const PathParam(this.name);
}

class Controller {
  final String prefix;
  const Controller(this.prefix);
}

class Protected {
  final List<String> roles;
  const Protected({this.roles = const []});
}

class Public {
  const Public();
}

class Header {
  final String name;
  const Header(this.name);
}

class CookieParam {
  final String name;
  const CookieParam(this.name);
}
''';

const _handler = '''
import '../annotations/annotations.dart';

abstract class RatelHandler {
  static final List<Route> routesList = [];

  static void register(Route route) => routesList.add(route);
}
''';

const _ormAnnotations = '''
class Column {
  final String name;
  const Column({required this.name});
}
''';

const _orm = '''
export 'annotations.dart';
''';
