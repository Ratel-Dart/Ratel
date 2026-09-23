import 'package:test/test.dart';

import 'support/generator_harness.dart';

const _imports = '''
import 'dart:io';

import 'package:ratel/annotations/annotations.dart';
import 'package:ratel/core/request_context.dart';
import 'package:ratel/http/handler.dart';
''';

void main() {
  test('registers a @Socket method by path', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class ChatController extends RatelHandler {
  @Socket('/ws')
  Future<void> chat(WebSocket socket) async {}
}
''',
    });

    expect(
      output,
      stringContainsInOrder([
        "_r.RatelHandler.registerSocket('/ws', (socket, ctx) async {",
        'await controller().chat(socket);',
      ]),
    );
  });

  test('passes the request context to a socket that asks for it', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class ChatController extends RatelHandler {
  @Socket('/ws')
  Future<void> chat(WebSocket socket, RequestContext ctx) async {}
}
''',
    });

    expect(output, contains('await controller().chat(socket, ctx);'));
  });

  test('prefixes a socket path with the @Controller prefix', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

@Controller('/live')
class ChatController extends RatelHandler {
  @Socket('/ws')
  Future<void> chat(WebSocket socket) async {}
}
''',
    });

    expect(output, contains("registerSocket('/live/ws'"));
  });

  test('leaves a controller without @Socket alone', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class PlainController extends RatelHandler {
  @Get('/ping')
  Future<String> ping() async => '';
}
''',
    });

    expect(output, isNot(contains('registerSocket')));
  });
}
