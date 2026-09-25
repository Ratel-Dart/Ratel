import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/seat_codec.dart';
import '../support/fixtures/codecs/ticket_codec.dart';
import '../support/fixtures/definitions/boom_controller_definition.dart';
import '../support/fixtures/definitions/secured_api_controller_definition.dart';
import '../support/fixtures/definitions/strict_input_controller_definition.dart';

void main() {
  const origin = 'https://app.example';
  const policy = "default-src 'none'";
  const manifest = RatelManifest(
    controllers: [
      SecuredApiControllerDefinition.value,
      StrictInputControllerDefinition.value,
      BoomControllerDefinition.value,
    ],
    jsonCodecs: [TicketCodec.definition, SeatCodec.definition],
  );
  List<Middleware> middlewares() => [
        CorsMiddleware.create(allowedOrigins: [origin]),
        SecurityHeadersMiddleware.create(contentSecurityPolicy: policy),
      ];
  final hookCalls = <Object>[];
  final plain = RatelServer(
    port: 0,
    jwtKey: 'secret',
    middlewares: middlewares(),
    registry: RatelRegistry.fromManifest(manifest),
  );
  final hooked = RatelServer(
    port: 0,
    jwtKey: 'secret',
    middlewares: middlewares(),
    registry: RatelRegistry.fromManifest(manifest),
    onError: (error, stackTrace, ctx) {
      hookCalls.add(error);
      return Response(
        statusCode: HttpStatus.serviceUnavailable,
        data: {'handled': true},
      );
    },
  );
  final client = HttpClient();

  setUpAll(() async {
    await plain.startServer();
    await hooked.startServer();
  });

  tearDownAll(() async {
    client.close(force: true);
    await plain.stop(force: true);
    await hooked.stop(force: true);
  });

  setUp(hookCalls.clear);

  Future<(HttpClientResponse, Map<String, dynamic>)> send(
    RatelServer server,
    String method,
    String path,
  ) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.boundPort}$path'),
    );
    request.headers.set('Origin', origin);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (response, jsonDecode(body) as Map<String, dynamic>);
  }

  List<LogRecord> recordLogs() {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    return records;
  }

  void expectDecorated(HttpClientResponse response) {
    expect(response.headers.value('access-control-allow-origin'), origin);
    expect(response.headers.value('vary'), contains('Origin'));
    expect(response.headers.value('x-frame-options'), 'DENY');
    expect(response.headers.value('referrer-policy'), 'no-referrer');
    expect(response.headers.value('content-security-policy'), policy);
  }

  test('a 401 from a protected route keeps the middleware headers', () async {
    final (response, body) = await send(plain, 'GET', '/secure');
    expect(response.statusCode, HttpStatus.unauthorized);
    expect(body['error'], isNotNull);
    expectDecorated(response);
  });

  test('a 400 from bad input keeps the middleware headers', () async {
    final (response, body) = await send(plain, 'GET', '/search');
    expect(response.statusCode, HttpStatus.badRequest);
    expect(body['error'], contains('"q"'));
    expectDecorated(response);
  });

  test('a 404 for an unknown route keeps the middleware headers', () async {
    final (response, body) = await send(plain, 'GET', '/nope');
    expect(response.statusCode, HttpStatus.notFound);
    expect(body['error'], 'Not Found');
    expectDecorated(response);
  });

  test('a 405 keeps its Allow header and the middleware headers', () async {
    final (response, body) = await send(plain, 'POST', '/public');
    expect(response.statusCode, HttpStatus.methodNotAllowed);
    expect(response.headers.value('allow'), 'GET');
    expect(body['error'], 'Method Not Allowed');
    expectDecorated(response);
  });

  test('a 500 from a throwing handler is decorated and logged once', () async {
    final records = recordLogs();

    final (response, body) = await send(plain, 'GET', '/boom');

    expect(response.statusCode, HttpStatus.internalServerError);
    expect(body['error'], 'Internal Server Error');
    final correlationId = body['correlationId'] as String;
    expectDecorated(response);
    final severe = records.where((record) => record.level == Level.SEVERE);
    expect(severe, hasLength(1));
    expect(
      severe.single.message,
      allOf(contains(correlationId), contains('GET /boom')),
    );
    expect(severe.single.error, isA<StateError>());
  });

  test('onError runs once and its response is decorated', () async {
    final records = recordLogs();

    final (response, body) = await send(hooked, 'GET', '/boom');

    expect(response.statusCode, HttpStatus.serviceUnavailable);
    expect(body, {'handled': true});
    expectDecorated(response);
    expect(hookCalls, hasLength(1));
    expect(hookCalls.single, isA<StateError>());
    expect(
      records.where((record) => record.level == Level.SEVERE),
      hasLength(1),
    );
  });

  test('onError is not called for an HttpStatusException', () async {
    final (response, _) = await send(hooked, 'GET', '/secure');
    expect(response.statusCode, HttpStatus.unauthorized);
    expectDecorated(response);
    expect(hookCalls, isEmpty);
  });
}
