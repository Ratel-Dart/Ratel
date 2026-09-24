import '../core/route_parameter.dart';

typedef RouteHandler = Future<dynamic> Function([dynamic request]);

class Route {
  final String path;

  final String method;

  final RouteHandler handler;

  final bool isProtected;

  final List<String> requiredRoles;

  final List<RouteParameter> parameters;

  final String? bodyType;

  Route({
    required this.path,
    required this.method,
    required this.handler,
    this.isProtected = false,
    this.requiredRoles = const [],
    this.parameters = const [],
    this.bodyType,
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

class Delete {
  final String path;

  const Delete(this.path);
}

class Put {
  final String path;

  const Put(this.path);
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

class Socket {
  final String path;

  const Socket(this.path);
}
