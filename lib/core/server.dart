import 'dart:async';
import 'dart:io';
import 'dart:mirrors';

import '../database/database.dart';
import '../dependency_injector/binding.dart';
import '../exceptions/exceptions.dart';
import '../http/handler.dart';
import '../jwt.dart';
import 'logger.dart';
import 'middleware.dart';
import 'request_context.dart';
import 'response.dart';
import 'router.dart';

/// The application entry point: binds an HTTP server, wires dependency
/// [bindings], registers the annotated [handlers], and dispatches each request
/// through the [middlewares] pipeline to its matching route.
///
/// JWT auth is added automatically as the innermost middleware when [jwtKey] is
/// set, enforcing protection and roles on routes. Provide a [securityContext]
/// to serve over HTTPS. Unexpected errors are logged server-side and answered
/// with a generic 500 (plus a correlation id) so no internal detail leaks.
class RatelServer {
  /// Port to listen on. Use `0` to let the OS pick a free port (handy in tests;
  /// read the chosen port via [boundPort]).
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

  /// Global middleware run, in order, around every request (e.g. CORS, security
  /// headers). The auth middleware is appended after these automatically.
  final List<Middleware> middlewares;

  /// Run once after binding, before serving begins.
  final Future<void> Function()? onStartup;

  /// Run once during [stop], after the socket is closed.
  final Future<void> Function()? onShutdown;

  /// Whether to gzip responses when the client advertises `Accept-Encoding:
  /// gzip` (HttpServer auto-compression). Defaults to true.
  final bool gzip;

  /// Idle keep-alive timeout for connections. When null, the `dart:io` default
  /// applies.
  final Duration? idleTimeout;

  HttpServer? _server;
  Router? _router;
  final List<StreamSubscription<ProcessSignal>> _signalSubs = [];
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
    this.middlewares = const [],
    this.onStartup,
    this.onShutdown,
    this.gzip = true,
    this.idleTimeout,
    int maxRequestBodyBytes = 1024 * 1024,
  }) {
    RatelHandler.maxRequestBodyBytes = maxRequestBodyBytes;
    bindings?.dependencies();
    _initializeHandlers();
  }

  /// The port the server is actually bound to, or null before [startServer].
  int? get boundPort => _server?.port;

  void _initializeHandlers() {
    for (var handlerType in handlers) {
      reflectClass(handlerType).newInstance(Symbol(''), []);
    }
  }

  /// Binds the socket and starts serving in the background. Completes once the
  /// server is listening; the process stays alive via the active socket until
  /// [stop] is called.
  Future<void> startServer() async {
    await onStartup?.call();

    final jwtMiddleware = jwtKey != null ? JwtAuthMiddleware(jwtKey!) : null;
    final server = securityContext != null
        ? await HttpServer.bindSecure(
            InternetAddress.anyIPv4, port, securityContext!)
        : await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.autoCompress = gzip;
    if (idleTimeout != null) {
      server.idleTimeout = idleTimeout!;
    }

    if (securityContext == null && jwtKey != null) {
      ratelLogger.warning(
        'Server is running over plain HTTP while JWT auth is enabled; bearer '
        'tokens will travel in cleartext. Provide a SecurityContext or '
        'terminate TLS at a trusted proxy.',
      );
    }

    _installSignalHandlers();
    _router = Router(RatelHandler.routes);

    final chain = <Middleware>[
      ...middlewares,
      if (jwtMiddleware != null) jwtAuthMiddleware(jwtMiddleware),
    ];

    unawaited(_serve(server, chain));
  }

  /// Stops accepting connections and runs [onShutdown]. With [force] true,
  /// in-flight requests are aborted instead of drained.
  Future<void> stop({bool force = false}) async {
    for (final sub in _signalSubs) {
      await sub.cancel();
    }
    _signalSubs.clear();
    await _server?.close(force: force);
    _server = null;
    await onShutdown?.call();
  }

  Future<void> _serve(HttpServer server, List<Middleware> chain) async {
    await for (final request in server) {
      try {
        await _handleRequest(request, chain);
      } catch (e, stackTrace) {
        ratelLogger.severe('Failed to handle request', e, stackTrace);
      }
    }
  }

  Future<void> _handleRequest(
    HttpRequest request,
    List<Middleware> chain,
  ) async {
    final ctx = RequestContext(request);
    var match = _router!.match(ctx.method, ctx.path);
    // Auto-HEAD: fall back to the GET route (the body is dropped in _terminal).
    match ??= ctx.method == 'HEAD' ? _router!.match('GET', ctx.path) : null;
    if (match != null) {
      ctx.route = match.route;
      ctx.pathParams = match.params;
    }
    final response = await _runChain(ctx, chain);
    await response.send(request.response);
  }

  Future<Response> _runChain(
    RequestContext ctx,
    List<Middleware> chain,
  ) async {
    Next next = () => _terminal(ctx);
    for (final middleware in chain.reversed) {
      final downstream = next;
      next = () => middleware(ctx, downstream);
    }
    try {
      return await next();
    } on HttpStatusException catch (e) {
      return Response(
        statusCode: e.statusCode,
        data: {'error': e.message},
        headers: e.headers,
      );
    } catch (e, stackTrace) {
      final correlationId = _nextCorrelationId();
      ratelLogger.severe(
        'Unhandled error [$correlationId] ${ctx.method} ${ctx.path}',
        e,
        stackTrace,
      );
      return Response(
        statusCode: HttpStatus.internalServerError,
        data: {
          'error': 'Internal Server Error',
          'correlationId': correlationId
        },
      );
    }
  }

  Future<Response> _terminal(RequestContext ctx) async {
    final route = ctx.route;
    if (route == null) {
      final allowed = _router!.allowedMethods(ctx.path);
      if (allowed.isNotEmpty) {
        throw MethodNotAllowedException(allowed);
      }
      throw const NotFoundException();
    }
    final result = await route.handler(ctx);
    final response = Response.from(result);
    if (ctx.method == 'HEAD') {
      // HEAD must mirror GET's status/headers but carry no body.
      return Response(
        statusCode: response.statusCode,
        headers: response.headers,
        contentType: response.contentType,
      )..cookies = response.cookies;
    }
    return response;
  }

  void _installSignalHandlers() {
    void handle(ProcessSignal signal) {
      _signalSubs.add(signal.watch().listen((_) async {
        ratelLogger.info('Received $signal, shutting down');
        await stop();
      }));
    }

    handle(ProcessSignal.sigint);
    if (!Platform.isWindows) {
      handle(ProcessSignal.sigterm);
    }
  }

  String _nextCorrelationId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$stamp-${_errorCounter++}';
  }
}
