import 'dart:io';
import 'dart:mirrors';

import '../annotations/annotations.dart';
import '../database/database.dart';
import '../dependency_injector/binding.dart';
import '../exceptions/exceptions.dart';
import '../http/handler.dart';
import '../jwt.dart';
import 'logger.dart';
import 'response.dart';

/// The application entry point: binds an HTTP server, wires dependency
/// [bindings], registers the annotated [handlers], and dispatches each request
/// to its matching route (enforcing JWT auth on protected routes when [jwtKey]
/// is set).
///
/// Provide a [securityContext] to serve over HTTPS. Unexpected errors are logged
/// server-side and answered with a generic 500 (plus a correlation id) so no
/// internal detail leaks to clients.
class RatelServer {
  /// Port to listen on.
  final int port;

  /// Optional database configuration (registers repositories when constructed).
  final RatelDatabase? database;

  /// Controller types to instantiate and scan for routes.
  final List<Type> handlers;

  /// HMAC secret enabling JWT auth; when null, no routes are protected.
  final String? jwtKey;

  /// Optional dependency registrations, run once at startup.
  final Bindings? bindings;

  /// When provided, the server listens over TLS via `bindSecure`.
  final SecurityContext? securityContext;

  static int _errorCounter = 0;

  /// Creates a server. [maxRequestBodyBytes] caps request body size (413 when
  /// exceeded); it defaults to 1 MiB.
  RatelServer({
    this.port = 8080,
    this.database,
    this.handlers = const [],
    this.jwtKey,
    this.bindings,
    this.securityContext,
    int maxRequestBodyBytes = 1024 * 1024,
  }) {
    RatelHandler.maxRequestBodyBytes = maxRequestBodyBytes;
    bindings?.dependencies();
    _initializeHandlers();
  }

  void _initializeHandlers() {
    for (var handlerType in handlers) {
      reflectClass(handlerType).newInstance(Symbol(''), []);
    }
  }

  /// Binds the socket and serves requests until the process exits.
  Future<void> startServer() async {
    final jwtMiddleware = jwtKey != null ? JwtAuthMiddleware(jwtKey!) : null;
    final server = securityContext != null
        ? await HttpServer.bindSecure(
            InternetAddress.anyIPv4, port, securityContext!)
        : await HttpServer.bind(InternetAddress.anyIPv4, port);

    if (securityContext == null && jwtKey != null) {
      ratelLogger.warning(
        'Server is running over plain HTTP while JWT auth is enabled; bearer '
        'tokens will travel in cleartext. Provide a SecurityContext or '
        'terminate TLS at a trusted proxy.',
      );
    }

    await for (final request in server) {
      try {
        await _handleRequest(request, jwtMiddleware);
      } catch (e, stackTrace) {
        // Last-resort guard so a failure while sending a response can never
        // tear down the accept loop.
        ratelLogger.severe('Failed to handle request', e, stackTrace);
      }
    }
  }

  Future<void> _handleRequest(
    HttpRequest request,
    JwtAuthMiddleware? jwtMiddleware,
  ) async {
    final path = request.uri.path;
    final method = request.method;
    try {
      Route? route;
      for (final r in RatelHandler.routes) {
        if (r.path == path && r.method == method) {
          route = r;
          break;
        }
      }
      if (route == null) {
        _sendError(request, HttpStatus.notFound, 'Not Found');
        return;
      }

      if (jwtMiddleware != null && route.isProtected) {
        final payload = await jwtMiddleware.validate(request);
        if (payload == null) {
          _sendError(
              request, HttpStatus.unauthorized, 'Invalid or missing token');
          return;
        }
      }

      final responseData = await route.handler(request);
      Response.from(responseData).send(request.response);
    } on HttpStatusException catch (e) {
      _sendError(request, e.statusCode, e.message);
    } catch (e, stackTrace) {
      final correlationId = _nextCorrelationId();
      ratelLogger.severe(
        'Unhandled error [$correlationId] $method $path',
        e,
        stackTrace,
      );
      _sendError(
        request,
        HttpStatus.internalServerError,
        'Internal Server Error',
        correlationId: correlationId,
      );
    }
  }

  void _sendError(
    HttpRequest request,
    int statusCode,
    String message, {
    String? correlationId,
  }) {
    final data = <String, dynamic>{'error': message};
    if (correlationId != null) {
      data['correlationId'] = correlationId;
    }
    Response(statusCode: statusCode, data: data).send(request.response);
  }

  String _nextCorrelationId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$stamp-${_errorCounter++}';
  }
}
