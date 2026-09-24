@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import '../support/cli_harness.dart';
import '../support/scratch_entities.dart';

void main() {
  late Directory workspace;
  late CliHarness cli;
  late Directory app;

  setUpAll(() async {
    workspace = await Directory.systemTemp.createTemp('ratel_e2e');
    cli = await CliHarness.compile(workspace);
    app = await cli.scaffold(workspace);
  });

  tearDownAll(() async {
    await workspace.delete(recursive: true);
  });

  test('ratel build compiles a binary that serves the scaffold', () async {
    final built = await cli.run(['build'], workingDirectory: app.path);
    expect(built.exitCode, 0, reason: '${built.stdout}${built.stderr}');
    final binary = p.join(
      app.path,
      'build',
      Platform.isWindows ? 'server.exe' : 'server',
    );
    expect(File(binary).existsSync(), isTrue);
    expect(
      Directory(app.path)
          .listSync(recursive: true)
          .where((entity) => entity.path.endsWith('.ratel.dart')),
      isEmpty,
    );

    final port = await CliHarness.freePort();
    final Process server;
    try {
      server = await Process.start(
        binary,
        const [],
        environment: {'PORT': '$port'},
      );
    } on ProcessException catch (error) {
      if (error.errorCode != CliHarness.applicationControlBlocked) rethrow;
      markTestSkipped(
        'This machine blocks freshly compiled binaries through Windows '
        'Application Control, so the built server could not be started.',
      );
      return;
    }
    addTearDown(() => CliHarness.kill(server));
    await CliHarness.until(
        () async => (await CliHarness.get(port, '/hello'))?.$1 == 200);
    final (_, body) = (await CliHarness.get(port, '/hello?name=Ada'))!;
    expect(jsonDecode(body), {'message': 'Hello, Ada!'});
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('plain dart run refuses to serve without the CLI', () async {
    final plain = await Process.run(
      DartSdk.dart,
      ['run', 'bin/server.dart'],
      workingDirectory: app.path,
    );
    expect(plain.exitCode, isNot(0));
    expect('${plain.stdout}${plain.stderr}', contains('ratel dev'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('ratel test wires the routes where plain dart test cannot', () async {
    final wired = await cli.run(['test'], workingDirectory: app.path);
    expect(wired.exitCode, 0, reason: '${wired.stdout}${wired.stderr}');
    final wrapper = File(p.join(app.path, '.dart_tool', 'ratel', 'test',
        'suites', 'test', 'hello_test.dart'));
    expect(wrapper.existsSync(), isTrue);

    final plain = await Process.run(
      DartSdk.dart,
      ['test'],
      workingDirectory: app.path,
    );
    expect(plain.exitCode, isNot(0));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
      'ratel dev serves, restarts on change, survives errors and dies with '
      'the CLI', () async {
    final port = await CliHarness.freePort();
    final dev = await cli.start(
      ['dev'],
      workingDirectory: app.path,
      environment: {'PORT': '$port'},
    );
    final output = StringBuffer();
    dev.stdout.transform(utf8.decoder).listen(output.write);
    dev.stderr.transform(utf8.decoder).listen(output.write);
    var killed = false;
    addTearDown(() async {
      if (!killed) await CliHarness.kill(dev);
    });

    await CliHarness.until(
      () async => (await CliHarness.get(port, '/hello'))?.$1 == 200,
    );

    final controller =
        File(p.join(app.path, 'lib', 'controllers', 'hello_controller.dart'));
    final original = controller.readAsStringSync();
    addTearDown(() => controller.writeAsStringSync(original));
    controller.writeAsStringSync(original.replaceFirst(
      '  @Get(\'/\')',
      "  @Get('/bye')\n"
          "  Future<Response> bye() async => Response.text(data: 'bye');\n"
          '\n'
          "  @Get('/')",
    ));
    await CliHarness.until(
      () async => (await CliHarness.get(port, '/hello/bye'))?.$2 == 'bye',
    );

    controller.writeAsStringSync(
      original.replaceFirst("name ?? 'world'", 'name.undefinedMember'),
    );
    await CliHarness.until(
      () async =>
          output.toString().contains('the previous server is still running'),
      timeout: const Duration(seconds: 60),
    );
    expect((await CliHarness.get(port, '/hello/bye'))?.$2, 'bye');

    await CliHarness.kill(dev, tree: false);
    killed = true;
    await CliHarness.until(
      () async => await CliHarness.get(port, '/hello') == null,
      timeout: const Duration(seconds: 20),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('ratel dev keeps refusing source changes while the runtime check fails',
      () async {
    final stub = Directory(p.join(workspace.path, 'orm_stub'));
    for (final MapEntry(key: path, value: contents)
        in ScratchEntities.ormStub.entries) {
      File(p.join(stub.path, path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(contents);
    }
    File(p.join(stub.path, 'pubspec.yaml')).writeAsStringSync(
      'name: ratel_orm\n\nenvironment:\n  sdk: ^3.6.0\n',
    );
    final script = Directory(p.join(workspace.path, 'stub_script'));
    final main = File(p.join(script.path, 'bin', 'main.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync("void main() {\n  print('first run');\n}\n");
    final pubspec = File(p.join(script.path, 'pubspec.yaml'))
      ..writeAsStringSync(
        'name: stub_script\npublish_to: none\n\nenvironment:\n'
        '  sdk: ^3.6.0\n\ndependencies:\n  ratel_orm:\n'
        '    path: ../orm_stub\n',
      );
    final resolved = await Process.run(
      DartSdk.dart,
      ['pub', 'get', '--offline'],
      workingDirectory: script.path,
    );
    expect(resolved.exitCode, 0,
        reason: '${resolved.stdout}${resolved.stderr}');

    final dev = await cli.start(['dev'], workingDirectory: script.path);
    final output = StringBuffer();
    dev.stdout.transform(utf8.decoder).listen(output.write);
    dev.stderr.transform(utf8.decoder).listen(output.write);
    addTearDown(() => CliHarness.kill(dev));

    Future<void> settled() async {
      var seen = output.length;
      var since = DateTime.now();
      await CliHarness.until(() async {
        if (output.length != seen) {
          seen = output.length;
          since = DateTime.now();
        }
        return DateTime.now().difference(since) > const Duration(seconds: 4);
      });
    }

    await CliHarness.until(
      () async => '$output'.contains('exited with code 0'),
    );
    expect('$output', contains('first run'));

    final runtime = File(p.join(stub.path, 'lib', 'runtime.dart'));
    final compatible = runtime.readAsStringSync();
    runtime.writeAsStringSync(
      compatible.replaceFirst('contract = 1', 'contract = 2'),
    );
    pubspec.writeAsStringSync('${pubspec.readAsStringSync()}\n');
    const refusal = 'a ratel_orm with contract 2';
    await CliHarness.until(() async => '$output'.contains(refusal));
    await settled();

    final before = output.length;
    final refusals = refusal.allMatches('$output').length;
    main.writeAsStringSync("void main() {\n  print('second run');\n}\n");
    await CliHarness.until(
      () async => refusal.allMatches('$output').length > refusals,
      timeout: const Duration(seconds: 60),
    );
    await settled();
    final afterEdit = '$output'.substring(before);
    expect(afterEdit, isNot(contains('[ratel] starting')));
    expect(afterEdit, isNot(contains('second run')));

    runtime.writeAsStringSync(compatible);
    pubspec.writeAsStringSync('${pubspec.readAsStringSync()}\n');
    await CliHarness.until(() async => '$output'.contains('second run'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
