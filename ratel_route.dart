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
