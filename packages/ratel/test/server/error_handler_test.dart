import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/boom_controller_definition.dart';

void main() {
  const manifest = RatelManifest(controllers: [BoomControllerDefinition.value]);
  final mapped = RatelServer(
    port: 0,
    logToConsole: false,
    registry: RatelRegistry.fromManifest(manifest),
    onError: (error, stackTrace, ctx) => Response(
      statusCode: HttpStatus.serviceUnavailable,
      data: {
        'handled': true,
        'path': ctx.path,
        'error': error.runtimeType.toString(),
      },
    ),
  );
  final failing = RatelServer(
    port: 0,
    logToConsole: false,
    registry: RatelRegistry.fromManifest(manifest),
    onError: (error, stackTrace, ctx) => throw StateError('the hook failed'),
  );
  final client = HttpClient();

  setUpAll(() async {
    await mapped.startServer();
    await failing.startServer();
  });

  tearDownAll(() async {
    client.close(force: true);
    await mapped.stop(force: true);
    await failing.stop(force: true);
  });

  Future<Map<String, dynamic>> boomOn(RatelServer server) async {
    final req = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/boom'));
    final res = await req.close();
    final body = jsonDecode(await res.transform(utf8.decoder).join());
    return {'status': res.statusCode, ...body as Map<String, dynamic>};
  }

  test('onError maps an unhandled error to a custom response', () async {
    final result = await boomOn(mapped);
    expect(result['status'], HttpStatus.serviceUnavailable);
    expect(result['handled'], isTrue);
    expect(result['path'], '/boom');
    expect(result['error'], 'StateError');
  });

  test('a hook that throws falls back to the generic 500', () async {
    final result = await boomOn(failing);
    expect(result['status'], HttpStatus.internalServerError);
    expect(result['error'], 'Internal Server Error');
    expect(result['correlationId'], isNotNull);
  });
}
