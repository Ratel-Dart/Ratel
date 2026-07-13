import 'dart:mirrors';

/// Signature of a compiled route handler.
///
/// The optional [request] is the incoming `HttpRequest`. It is declared
/// optional so the same type can describe handlers that ignore the request.
typedef RouteHandler = Future<dynamic> Function([dynamic request]);

/// A single registered HTTP route.
///
/// Created by [RatelHandler] while scanning a controller for method
/// annotations. It holds the matched [path] and HTTP [method], the compiled
/// [handler] that binds parameters and invokes the user's method, whether the
/// route [isProtected] by authentication, and the [methodMirror] used for
/// reflective parameter binding.
class Route {
  /// The URL path this route matches (e.g. `/users`).
  final String path;

  /// The HTTP method this route matches (e.g. `GET`).
  final String method;

  /// Compiled closure that binds request data and invokes the controller method.
  final RouteHandler handler;

  /// Whether this route requires a valid authentication token.
  final bool isProtected;

  /// Roles the caller must hold (any one is sufficient) when [isProtected]. An
  /// empty list means authentication is enough, with no role check.
  final List<String> requiredRoles;

  /// Reflective handle on the controller method, used for parameter binding.
  final MethodMirror? methodMirror;

  /// Creates a route. Only [path], [method] and [handler] are required.
  Route({
    required this.path,
    required this.method,
    required this.handler,
    this.isProtected = false,
    this.requiredRoles = const [],
    this.methodMirror,
  });
}

/// Binds the annotated method to HTTP `GET` requests on [path].
class Get {
  /// The URL path to match.
  final String path;

  /// Binds the method to `GET [path]`.
  const Get(this.path);
}

/// Binds the annotated method to HTTP `POST` requests on [path].
class Post {
  /// The URL path to match.
  final String path;

  /// Binds the method to `POST [path]`.
  const Post(this.path);
}

/// Binds the annotated method to HTTP `DELETE` requests on [path].
class Delete {
  /// The URL path to match.
  final String path;

  /// Binds the method to `DELETE [path]`.
  const Delete(this.path);
}

/// Binds the annotated method to HTTP `PUT` requests on [path].
class Put {
  /// The URL path to match.
  final String path;

  /// Binds the method to `PUT [path]`.
  const Put(this.path);
}

/// Binds the annotated method to HTTP `PATCH` requests on [path].
class Patch {
  /// The URL path to match.
  final String path;

  /// Binds the method to `PATCH [path]`.
  const Patch(this.path);
}

/// Binds the annotated method to HTTP `HEAD` requests on [path].
class Head {
  /// The URL path to match.
  final String path;

  /// Binds the method to `HEAD [path]`.
  const Head(this.path);
}

/// Binds the annotated method to HTTP `OPTIONS` requests on [path].
class Options {
  /// The URL path to match.
  final String path;

  /// Binds the method to `OPTIONS [path]`.
  const Options(this.path);
}

/// Marks a handler parameter as the deserialized request body.
///
/// The parameter type must be a class annotated with [Json].
class Body {
  /// Marks the parameter as the request body.
  const Body();
}

/// Marks a class as JSON-serializable so the framework can (de)serialize it for
/// request bodies and responses.
class Json {
  /// Marks the class as JSON-serializable.
  const Json();
}

/// Marks a handler parameter as bound to a query-string parameter of the same
/// name.
class Param {
  /// Marks the parameter as a query-string parameter.
  const Param();
}

/// Marks a handler parameter as bound to a path parameter named [name], i.e. a
/// `:name` segment in the route path (e.g. `/users/:id` with `@PathParam('id')`).
class PathParam {
  /// The path segment name this parameter binds to.
  final String name;

  /// Binds the parameter to the `:[name]` path segment.
  const PathParam(this.name);
}

/// Class-level annotation that prefixes every route in a controller with
/// [prefix] (e.g. `@Controller('/api/v1')`).
class Controller {
  /// The base path prepended to each route in the controller.
  final String prefix;

  /// Prefixes the controller's routes with [prefix].
  const Controller(this.prefix);
}

/// Requires a valid authentication token to reach the annotated controller or
/// method. See [Public] to opt a single method out of a protected controller.
///
/// Pass [roles] to additionally require the caller to hold at least one of the
/// listed roles (a 403 is returned otherwise).
class Protected {
  /// Roles the caller must hold (any one suffices). Empty means "any
  /// authenticated caller".
  final List<String> roles;

  /// Marks the controller or method as authentication-protected, optionally
  /// restricted to [roles].
  const Protected({this.roles = const []});
}

/// Opts a single method out of authentication on an otherwise [Protected]
/// controller.
class Public {
  /// Marks the method as publicly accessible.
  const Public();
}

/// Marks a handler parameter as bound to the request header named [name].
class Header {
  /// The request header name this parameter binds to.
  final String name;

  /// Binds the parameter to the `[name]` request header.
  const Header(this.name);
}

/// Marks a handler parameter as bound to the request cookie named [name].
///
/// Named `CookieParam` to avoid colliding with `dart:io`'s `Cookie`.
class CookieParam {
  /// The cookie name this parameter binds to.
  final String name;

  /// Binds the parameter to the `[name]` request cookie.
  const CookieParam(this.name);
}
