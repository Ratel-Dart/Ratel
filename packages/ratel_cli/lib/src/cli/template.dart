import 'dart:io';

import 'package:path/path.dart' as p;
import 'version.dart';

Future<void> scaffold(Directory target, String version) async {
  final name = _packageName(p.basename(p.absolute(target.path)));
  target.createSync(recursive: true);

  _write(target, 'pubspec.yaml', '''
name: $name
description: A Ratel backend application.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.6.0

dependencies:
  ratel: ^$version

dev_dependencies:
  build_runner: ^2.4.0
  lints: ^4.0.0
  ratel_generator: ^${RatelCliVersion.generator}
  test: ^1.25.0
''');

  _write(target, 'analysis_options.yaml', '''
include: package:lints/recommended.yaml

analyzer:
  exclude:
    - "**/*.ratel.dart"
''');

  _write(target, '.gitignore', '''
.dart_tool/
build/
pubspec.lock

*.ratel.dart
''');

  _write(target, p.join('lib', 'controllers', 'hello_controller.dart'), '''
import 'package:ratel/ratel.dart';

@Json()
class Greeting {
  String message;

  Greeting({this.message = ''});
}

@Controller('/hello')
class HelloController extends RatelHandler {
  @Get('/')
  Future<Response> hello(@Param() String? name) async {
    return Response.json(data: Greeting(message: 'Hello, \${name ?? 'world'}!'));
  }
}
''');

  _write(target, p.join('bin', 'server.dart'), '''
import 'dart:io';

import 'package:ratel/ratel.dart';

Future<void> main() async {
  final server = RatelServer(port: 8080);
  await server.startServer();
  stdout.writeln('Listening on http://localhost:\${server.boundPort}');
}
''');

  _write(target, 'README.md', '''
# $name

A [Ratel](https://github.com/Ratel-Dart/Ratel) backend application.

## Run

```
ratel dev
```

Then: `curl "http://localhost:8080/hello?name=Ada"`

## Build a native binary

```
ratel build
./build/server
```
''');
}

void _write(Directory target, String relativePath, String contents) {
  final file = File(p.join(target.path, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

String _packageName(String raw) {
  final sanitized =
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_').replaceAll(
            RegExp(r'_+'),
            '_',
          );
  final trimmed = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
  if (trimmed.isEmpty || RegExp(r'^[0-9]').hasMatch(trimmed)) {
    return 'ratel_app';
  }
  return trimmed;
}
