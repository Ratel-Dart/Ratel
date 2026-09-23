/// Where a route parameter is read from.
enum ParameterLocation {
  /// A `:name` segment of the route path, bound with `@PathParam`.
  path,

  /// A query-string parameter, bound with `@Param`.
  query,

  /// A request header, bound with `@Header`.
  header,

  /// A request cookie, bound with `@CookieParam`.
  cookie,
}
