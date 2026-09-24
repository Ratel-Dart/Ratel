import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class ProjectScaffold {
  static void create(Directory target, String ratelVersion) {
    final name = packageName(p.basename(p.absolute(target.path)));
    target.createSync(recursive: true);
    _write(target, 'pubspec.yaml', _pubspec(name, ratelVersion));
    _write(target, 'analysis_options.yaml', _analysisOptions);
    _write(target, '.gitignore', _gitignore);
    _write(target, p.join('lib', 'models', 'greeting.dart'), _greeting);
    _write(
      target,
      p.join('lib', 'controllers', 'hello_controller.dart'),
      _helloController(name),
    );
    _write(target, p.join('bin', 'server.dart'), _server);
    _write(target, p.join('test', 'hello_test.dart'), _helloTest);
    _write(target, 'README.md', _readme(name));
  }

  static String packageName(String raw) {
    final sanitized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final trimmed = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
    if (trimmed.isEmpty || RegExp(r'^[0-9]').hasMatch(trimmed)) {
      return 'ratel_app';
    }
    return trimmed;
  }

  static void _write(Directory target, String relativePath, String contents) {
    final file = File(p.join(target.path, relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  static String _pubspec(String name, String ratelVersion) => '''
name: $name
description: A Ratel backend application.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.6.0

dependencies:
  ratel: ^$ratelVersion

dev_dependencies:
  lints: ^4.0.0
  test: ^1.25.0
''';

  static const _analysisOptions = '''
include: package:lints/recommended.yaml
''';

  static const _gitignore = '''
.dart_tool/
build/
pubspec.lock
''';

  static const _greeting = '''
import 'package:ratel/ratel.dart';

@Json()
class Greeting {
  Greeting({this.message = ''});

  String message;
}
''';

  static String _helloController(String name) => '''
import 'package:$name/models/greeting.dart';
import 'package:ratel/ratel.dart';

@Controller('/hello')
class HelloController {
  @Get('/')
  Future<Response> hello(@Param() String? name) async {
    return Response.json(data: Greeting(message: 'Hello, \${name ?? 'world'}!'));
  }
}
''';

  static const _server = '''
import 'dart:io';

import 'package:ratel/ratel.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = RatelServer(port: port);
  await server.startServer();
  stdout.writeln('Listening on http://localhost:\${server.boundPort}');
}
''';

  static const _helloTest = '''
import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  late RatelServer server;

  setUpAll(() async {
    server = RatelServer(port: 0);
    await server.startServer();
  });

  tearDownAll(() => server.stop(force: true));

  test('GET /hello greets the caller', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final request =
        await client.get('localhost', server.boundPort!, '/hello?name=Ada');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    expect(jsonDecode(body), {'message': 'Hello, Ada!'});
  });
}
''';

  static String _readme(String name) => '''
# $name

A [Ratel](https://github.com/Ratel-Dart/Ratel) backend application.

## Run

```
ratel dev
```

Then open `http://localhost:8080/hello?name=Ada`. The server restarts whenever
a file changes. Set `PORT` to listen elsewhere.

Start the app through `ratel`, not `dart run`: the CLI discovers the
`@Controller` classes and wires their routes before `main` runs.

## Test

```
ratel test
```

`ratel test` wires the routes before each test file runs, so a test can start
a `RatelServer` and call it over HTTP. A test that calls a controller directly
also runs with plain `dart test`.

## Build a native binary

```
ratel build
```

The binary lands in `build/`.
''';
}
