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

  /// Reflective handle on the controller method, used for parameter binding.
  final MethodMirror? methodMirror;

  /// Creates a route. All fields except [isProtected] and [methodMirror] are
  /// required.
  Route({
    required this.path,
    required this.method,
    required this.handler,
    this.isProtected = false,
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

/// Maps a model field to a database column named [name].
class Column {
  /// The database column name this field maps to.
  final String name;

  /// Maps the annotated field to the column [name].
  const Column({
    required this.name,
  });
}

/// Requires a valid authentication token to reach the annotated controller or
/// method. See [Public] to opt a single method out of a protected controller.
class Protected {
  /// Marks the controller or method as authentication-protected.
  const Protected();
}

/// Opts a single method out of authentication on an otherwise [Protected]
/// controller.
class Public {
  /// Marks the method as publicly accessible.
  const Public();
}
