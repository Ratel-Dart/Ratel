class Route {
  final String path;
  final String method;
  final Function handler;

  Route({
    required this.path,
    required this.method,
    required this.handler,
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

class Table {
  final String? tableName;
  const Table({this.tableName});
}

class Column {
  final String name;

  const Column({
    required this.name,
  });
}
