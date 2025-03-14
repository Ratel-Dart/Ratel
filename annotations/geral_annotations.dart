import 'dart:mirrors';

typedef RouteHandler = Future<dynamic> Function([dynamic request]);

class Route {
  final String path;
  final String method;
  final RouteHandler handler;
  final bool isProtected;
  final MethodMirror? methodMirror;

  Route({
    required this.path,
    required this.method,
    required this.handler,
    this.isProtected = false,
    this.methodMirror,
  });
}

class HttpMethod {
  final String path;
  final String method;
  const HttpMethod(this.path, this.method);
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

class Body {
  const Body();
}

class Json {
  const Json();
}

class Param {
  const Param();
}

// class Table {
//   final String? tableName;
//   const Table({this.tableName});
// }

class Column {
  final String name;

  const Column({
    required this.name,
  });
}

class Protected {
  const Protected();
}

class Public {
  const Public();
}

class Auth {
  static String? jwtKey;
}
