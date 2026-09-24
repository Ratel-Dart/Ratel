import 'dart:async';
import 'dart:io';

import '../database/db.dart';
import '../database/driver.dart';
import '../dependency_injector/binding.dart';
import '../exceptions/exceptions.dart';
import '../jwt.dart';
import 'error_handler.dart';
import 'logger.dart';
import 'middleware.dart';
import 'ratel_registry.dart';
import 'request_context.dart';
import 'response.dart';
import 'router.dart';

class RatelServer {
  final int port;

  final RatelDriver? database;

  final String? jwtKey;

  final Bindings? bindings;

  final SecurityContext? securityContext;

  final List<Middleware> middlewares;

  final Future<void> Function()? onStartup;

  final Future<void> Function()? onShutdown;

  final bool gzip;

  final Duration? idleTimeout;

  final bool shared;

  final RatelRegistry registry;

  final ErrorHandler? onError;

  HttpServer? _server;
  Router? _router;
  final List<StreamSubscription<ProcessSignal>> _signalSubs = [];
  int _errorCounter = 0;

  RatelServer({
    this.port = 8080,
    this.database,
    this.jwtKey,
    this.bindings,
    this.securityContext,
    this.middlewares = const [],
    this.onStartup,
    this.onShutdown,
    this.gzip = true,
    this.idleTimeout,
    this.onError,
    this.shared = false,
    RatelRegistry? registry,
    int maxRequestBodyBytes = RatelRegistry.defaultMaxRequestBodyBytes,
    int maxBodyDrainBytes = RatelRegistry.defaultMaxBodyDrainBytes,
  }) : registry = registry ?? RatelRegistry.current {
    this.registry.maxRequestBodyBytes = maxRequestBodyBytes;
    this.registry.maxBodyDrainBytes = maxBodyDrainBytes;
    bindings?.dependencies();
  }

  int? get boundPort => _server?.port;

  Db get db => Db(database);

  Future<void> startServer() async {
    final driver = database;
    if (driver != null) {
      Db.configure(driver);
      await driver.open();
    }

    await onStartup?.call();

    final jwtMiddleware = jwtKey != null ? JwtAuthMiddleware(jwtKey!) : null;
    final server = securityContext != null
        ? await HttpServer.bindSecure(
            InternetAddress.anyIPv4,
            port,
            securityContext!,
            shared: shared,
          )
        : await HttpServer.bind(InternetAddress.anyIPv4, port, shared: shared);
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
    _router = Router(registry.routes);

    final chain = <Middleware>[
      ...middlewares,
      if (jwtMiddleware != null) jwtAuthMiddleware(jwtMiddleware),
    ];

    unawaited(_serve(server, chain));
  }

  Future<void> stop({bool force = false}) async {
    for (final sub in _signalSubs) {
      await sub.cancel();
    }
    _signalSubs.clear();
    await _server?.close(force: force);
    _server = null;
    await onShutdown?.call();
    await database?.close();
  }

  Future<void> _serve(HttpServer server, List<Middleware> chain) async {
    await for (final request in server) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        unawaited(_upgrade(request));
        continue;
      }
      unawaited(_dispatch(request, chain));
    }
  }

  Future<void> _dispatch(HttpRequest request, List<Middleware> chain) async {
    try {
      await _handleRequest(request, chain);
    } catch (e, stackTrace) {
      ratelLogger.severe('Failed to handle request', e, stackTrace);
    }
  }

  Future<void> _upgrade(HttpRequest request) async {
    final handler = registry.socketFor(request.uri.path);
    if (handler == null) {
      Response(
        statusCode: HttpStatus.notFound,
        data: {'error': 'Not Found'},
      ).send(request.response);
      return;
    }
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      await handler(socket, RequestContext(request, registry: registry));
    } catch (e, stackTrace) {
      ratelLogger.severe('Failed to handle a socket upgrade', e, stackTrace);
    }
  }

  Future<void> _handleRequest(
    HttpRequest request,
    List<Middleware> chain,
  ) async {
    final ctx = RequestContext(request, registry: registry);
    final match = _router!.match(ctx.method, ctx.path) ?? _getRouteForHead(ctx);
    if (match != null) {
      ctx.route = match.route;
      ctx.pathParams = match.params;
    }
    final response = await _runChain(ctx, chain);
    await response.send(request.response, includeBody: ctx.method != 'HEAD');
  }

  RouteMatch? _getRouteForHead(RequestContext ctx) {
    if (ctx.method != 'HEAD') return null;
    return _router!.match('GET', ctx.path);
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
      return await _handleError(e, stackTrace, ctx) ??
          Response(
            statusCode: HttpStatus.internalServerError,
            data: {
              'error': 'Internal Server Error',
              'correlationId': correlationId
            },
          );
    }
  }

  Future<Response?> _handleError(
    Object error,
    StackTrace stackTrace,
    RequestContext ctx,
  ) async {
    final hook = onError;
    if (hook == null) return null;
    try {
      return await hook(error, stackTrace, ctx);
    } catch (hookError, hookStack) {
      ratelLogger.severe('onError hook threw', hookError, hookStack);
      return null;
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
    return Response.from(result);
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
