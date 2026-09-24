import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/model/generation_mode.dart';
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import '../support/engine_harness.dart';

void main() {
  final output = EngineHarness.output('kitchen_sink', GenerationMode.build);
  final manifest = p.join(output, 'ratel_app_manifest.dart');
  final entry = p.join(output, 'server.dart');

  setUpAll(() async {
    final result = await EngineHarness.generate(
      'kitchen_sink',
      packageName: 'kitchen_sink_app',
      write: true,
    );
    expect(result.hasErrors, isFalse, reason: '${result.diagnostics}');
  });

  test('writes a manifest and an entry named after the entrypoint', () {
    expect(File(manifest).existsSync(), isTrue);
    expect(File(entry).existsSync(), isTrue);
  });

  test('the generated code analyzes with no errors or warnings', () async {
    final collection = AnalysisContextCollection(
      includedPaths: [manifest, entry],
      sdkPath: DartSdk.root,
    );
    addTearDown(collection.dispose);
    for (final path in [manifest, entry]) {
      final result = await collection
          .contextFor(path)
          .currentSession
          .getResolvedUnit(path);
      final problems = (result as ResolvedUnitResult)
          .diagnostics
          .where((diagnostic) => diagnostic.severity != Severity.info)
          .map((diagnostic) => diagnostic.message)
          .toList();
      expect(problems, isEmpty, reason: path);
    }
  });

  test('the generated code carries no comments', () {
    for (final path in [manifest, entry]) {
      final unit = parseString(content: File(path).readAsStringSync()).unit;
      Token? token = unit.beginToken;
      while (token != null && token.type != TokenType.EOF) {
        expect(token.precedingComments, isNull, reason: path);
        token = token.next;
      }
    }
  });

  test('the entry holds only main and the manifest only one class', () {
    List<CompilationUnitMember> declarations(String path) =>
        parseString(content: File(path).readAsStringSync()).unit.declarations;
    final entryDeclarations = declarations(entry);
    expect(entryDeclarations, hasLength(1));
    expect(
      (entryDeclarations.single as FunctionDeclaration).name.lexeme,
      'main',
    );
    final manifestDeclarations = declarations(manifest);
    expect(manifestDeclarations, hasLength(1));
    expect(manifestDeclarations.single, isA<ClassDeclaration>());
  });

  test('generates a codec for every DTO the route signatures reach', () {
    final source = File(manifest).readAsStringSync();
    for (final type in ['Item', 'Tag', r'Page<i\d+\.Item>']) {
      expect(
        source,
        matches(RegExp('JsonCodecDefinition<i\\d+\\.$type>\\(')),
        reason: type,
      );
    }
  });

  group('the generated program', () {
    late Process process;
    late int port;

    Future<(int, String)> send(
      String method,
      String path, {
      Map<String, String> headers = const {},
      List<Cookie> cookies = const [],
      List<int>? body,
    }) async {
      final client = HttpClient();
      try {
        final request = await client.openUrl(
          method,
          Uri.parse('http://127.0.0.1:$port$path'),
        );
        headers.forEach(request.headers.set);
        request.cookies.addAll(cookies);
        if (body != null) request.add(body);
        final response = await request.close();
        return (
          response.statusCode,
          await response.transform(utf8.decoder).join(),
        );
      } finally {
        client.close(force: true);
      }
    }

    setUpAll(() async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = probe.port;
      await probe.close();
      process = await Process.start(
        DartSdk.dart,
        ['run', entry, '$port'],
        workingDirectory: EngineHarness.fixture('kitchen_sink'),
      );
      final ready = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line.startsWith('listening'));
      process.stderr.transform(utf8.decoder).listen(stderr.write);
      await ready.timeout(const Duration(seconds: 90));
    });

    tearDownAll(() async {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
      } else {
        process.kill();
      }
      await process.exitCode;
    });

    test('binds path and query parameters', () async {
      final (status, body) = await send('GET', '/items/7?view=full');
      expect(status, 200);
      expect(jsonDecode(body), {'id': 7, 'view': 'full'});
    });

    test('binds headers, cookies and the request context', () async {
      final (_, body) = await send(
        'GET',
        '/items',
        headers: {'X-Trace': 't-1'},
        cookies: [Cookie('session', 's-1')],
      );
      expect(jsonDecode(body),
          {'trace': 't-1', 'session': 's-1', 'path': '/items'});
    });

    Future<(int, Object?)> post(
      String body, {
      String contentType = 'application/json',
    }) async {
      final (status, response) = await send(
        'POST',
        '/items',
        headers: {'content-type': contentType},
        body: utf8.encode(body),
      );
      return (status, jsonDecode(response));
    }

    test('decodes and encodes a nested body with the generated codecs',
        () async {
      final item = {
        'id': 3,
        'name': 'lamp',
        'tags': [
          {'name': 'light'},
          {'name': 'desk'},
        ],
        'status': 'published',
        'createdAt': '2026-01-02T03:04:05.000Z',
      };
      final (status, body) = await post(jsonEncode(item));
      expect(status, 201);
      expect(body, {...item, 'label': '3:lamp'});
    });

    test('applies constructor defaults for missing keys', () async {
      final (status, body) = await post('{"id":3,"name":"lamp"}');
      expect(status, 201);
      expect(body, {
        'id': 3,
        'name': 'lamp',
        'tags': <Object?>[],
        'status': 'draft',
        'createdAt': null,
        'label': '3:lamp',
      });
    });

    test('answers 400 naming a field of the wrong type', () async {
      final (status, body) = await post('{"id":"x"}');
      expect(status, 400);
      expect(body, {'error': 'Field "id" must be an integer'});
    });

    test('answers 400 naming a missing required field', () async {
      final (status, body) = await post('{}');
      expect(status, 400);
      expect(body, {'error': 'Field "id" is required'});
    });

    test('answers 400 naming an unknown enum value', () async {
      final (status, body) =
          await post('{"id":3,"name":"lamp","status":"lost"}');
      expect(status, 400);
      expect(body, {
        'error': 'Field "status" must be one of draft, published, archived',
      });
    });

    test('decodes a form body into the same DTO', () async {
      final (status, body) = await post(
        'id=3&name=lamp',
        contentType: 'application/x-www-form-urlencoded',
      );
      expect(status, 201);
      expect(body, containsPair('id', 3));
      expect(body, containsPair('label', '3:lamp'));
    });

    test('treats a blank form field as a missing one', () async {
      final (status, body) = await post(
        'id=3&name=lamp&createdAt=&status=',
        contentType: 'application/x-www-form-urlencoded',
      );
      expect(status, 201);
      expect(body, containsPair('createdAt', null));
      expect(body, containsPair('status', 'draft'));
    });

    List<int> multipart(Map<String, String> fields, {String? file}) =>
        utf8.encode([
          for (final MapEntry(:key, :value) in fields.entries) ...[
            '--RATEL',
            'Content-Disposition: form-data; name="$key"',
            '',
            value,
          ],
          if (file != null) ...[
            '--RATEL',
            'Content-Disposition: form-data; name="file"; filename="$file"',
            'Content-Type: text/plain',
            '',
            'hello',
          ],
          '--RATEL--',
          '',
        ].join('\r\n'));

    test('decodes a multipart body into the DTO next to its files', () async {
      final (status, body) = await send(
        'POST',
        '/items/upload',
        headers: {'content-type': 'multipart/form-data; boundary=RATEL'},
        body: multipart(
          {'id': '3', 'name': 'lamp', 'status': 'published'},
          file: 'a.txt',
        ),
      );
      expect(status, 200);
      expect(jsonDecode(body), {'files': 1, 'name': 'lamp'});
    });

    test('decodes a multipart body into a DTO-only route', () async {
      final (status, body) = await send(
        'POST',
        '/items',
        headers: {'content-type': 'multipart/form-data; boundary=RATEL'},
        body: multipart({'id': '3', 'name': 'lamp', 'status': 'published'}),
      );
      expect(status, 201);
      expect(jsonDecode(body), containsPair('status', 'published'));
    });

    test('answers HEAD on a route that returns a DTO without a body', () async {
      final (status, body) = await send('HEAD', '/catalog/featured');
      expect(status, 200);
      expect(body, isEmpty);
    });

    test('encodes a DTO a route returns directly', () async {
      final (status, body) = await send('GET', '/catalog/featured');
      expect(status, 200);
      expect(jsonDecode(body), {
        'id': 1,
        'name': 'lamp',
        'tags': [
          {'name': 'light'},
          {'name': 'desk'},
        ],
        'status': 'published',
        'createdAt': '2026-01-02T03:04:05.000Z',
        'label': '1:lamp',
      });
    });

    test('encodes a list of DTOs a route returns', () async {
      final (status, body) = await send('GET', '/catalog/all');
      expect(status, 200);
      expect(
        (jsonDecode(body) as List).map((item) => (item as Map)['label']),
        ['1:lamp', '2:chair'],
      );
    });

    test('encodes a generic DTO a route returns', () async {
      final (status, body) = await send('GET', '/catalog/page');
      expect(status, 200);
      expect(jsonDecode(body), {
        'items': [
          {
            'id': 1,
            'name': 'lamp',
            'tags': <Object?>[],
            'status': 'draft',
            'createdAt': null,
            'label': '1:lamp',
          },
        ],
        'total': 7,
      });
    });

    test('keeps protected routes behind the JWT middleware', () async {
      final (status, _) = await send('GET', '/items/admin/secret');
      expect(status, 401);
    });

    test('builds a controller with dependencies through the injector',
        () async {
      final (status, body) = await send('GET', '/greet?name=Ada');
      expect(status, 200);
      expect(body, 'Ahoy, Ada');
    });

    test('serves a controller nothing imports', () async {
      final (_, body) = await send('GET', '/health');
      expect(jsonDecode(body), {'ok': true});
    });

    test('hands the socket and the context to a socket route', () async {
      final socket = await WebSocket.connect('ws://127.0.0.1:$port/items/ws');
      expect(await socket.first, 'hello /items/ws');
    });

    test('refuses a protected socket upgrade without a token', () async {
      await expectLater(
        WebSocket.connect('ws://127.0.0.1:$port/items/admin/ws'),
        throwsA(isA<WebSocketException>().having(
          (error) => error.httpStatusCode,
          'httpStatusCode',
          401,
        )),
      );
    });

    test('refuses a protected socket upgrade with an invalid token', () async {
      await expectLater(
        WebSocket.connect(
          'ws://127.0.0.1:$port/items/member/ws',
          headers: {HttpHeaders.authorizationHeader: 'Bearer not-a-token'},
        ),
        throwsA(isA<WebSocketException>().having(
          (error) => error.httpStatusCode,
          'httpStatusCode',
          401,
        )),
      );
    });
  });
}
