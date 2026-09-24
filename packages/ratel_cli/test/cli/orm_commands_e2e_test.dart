@Tags(['e2e', 'orm'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import '../support/cli_harness.dart';
import '../support/orm_fixture.dart';

void main() {
  const scriptOutput = [
    'created #1 Buy milk open 2026-01-02T03:04:05.000Z',
    'found #1 Buy milk body=null',
    'updated #1 done archived=true',
    'done Buy milk',
    'deleted true',
    'remaining 0',
  ];

  late Directory workspace;
  late CliHarness cli;
  late Directory ormOnly;
  late Directory ormApp;

  setUpAll(() async {
    workspace = await Directory.systemTemp.createTemp('ratel_orm_e2e');
    cli = await CliHarness.compile(workspace);
    ormOnly = await OrmFixture.copy('orm_only', workspace);
    ormApp = await OrmFixture.copy('orm_app', workspace);
  });

  tearDownAll(() => workspace.delete(recursive: true));

  Future<(Process, StringBuffer)> start(
    List<String> arguments,
    Directory app, {
    Map<String, String> environment = const {},
  }) async {
    final process = await cli.start(
      arguments,
      workingDirectory: app.path,
      environment: environment,
    );
    final output = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(output.write);
    process.stderr.transform(utf8.decoder).listen(output.write);
    addTearDown(() => CliHarness.kill(process));
    return (process, output);
  }

  Future<void> waitFor(
    Future<bool> Function() condition,
    StringBuffer output,
  ) async {
    try {
      await CliHarness.until(condition);
    } on TimeoutException {
      fail('Timed out; the CLI printed:\n$output');
    }
  }

  Future<(int, String)> send(
    int port,
    String method,
    String path, [
    Map<String, Object?>? json,
  ]) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:$port$path'),
      );
      if (json != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(json));
      }
      final response = await request.close();
      return (
        response.statusCode,
        await response.transform(utf8.decoder).join(),
      );
    } finally {
      client.close(force: true);
    }
  }

  test('plain dart run fails at the first repository and names ratel dev',
      () async {
    final plain = await Process.run(
      DartSdk.dart,
      ['run', 'bin/main.dart'],
      workingDirectory: ormOnly.path,
    );
    expect(plain.exitCode, isNot(0));
    expect(
      '${plain.stdout}${plain.stderr}',
      allOf(
        contains('No Ratel ORM entity manifest is installed'),
        contains('ratel dev'),
      ),
    );
  });

  test('ratel build compiles an ORM-only script into a binary', () async {
    final built = await cli.run(['build'], workingDirectory: ormOnly.path);
    expect(built.exitCode, 0, reason: '${built.stdout}${built.stderr}');
    expect(
      File(p.join(ormOnly.path, '.dart_tool', 'ratel', 'build',
              'ratel_app_manifest.dart'))
          .existsSync(),
      isFalse,
    );
    final binary = p.join(
      ormOnly.path,
      'build',
      Platform.isWindows ? 'main.exe' : 'main',
    );
    expect(File(binary).existsSync(), isTrue);

    final ProcessResult ran;
    try {
      ran = await Process.run(binary, const [], workingDirectory: ormOnly.path);
    } on ProcessException catch (error) {
      if (error.errorCode != CliHarness.applicationControlBlocked) rethrow;
      markTestSkipped(
        'This machine blocks freshly compiled binaries through Windows '
        'Application Control, so the built script could not be started.',
      );
      return;
    }
    expect(ran.exitCode, 0, reason: '${ran.stdout}${ran.stderr}');
    expect(LineSplitter.split('${ran.stdout}'), scriptOutput);
  });

  test('ratel test installs the entity manifest where plain dart test cannot',
      () async {
    final wired = await cli.run(['test'], workingDirectory: ormOnly.path);
    expect(wired.exitCode, 0, reason: '${wired.stdout}${wired.stderr}');
    final wrapper = File(p.join(ormOnly.path, '.dart_tool', 'ratel', 'test',
            'suites', 'test', 'note_repository_test.dart'))
        .readAsStringSync();
    expect(
      wrapper,
      contains('o.RatelOrmRuntime.install(RatelEntityManifest.manifest);'),
    );
    expect(wrapper, isNot(contains('package:ratel/')));
    expect(wrapper, startsWith("@Tags(['fixture'])\nlibrary;\n"));

    final plain = await Process.run(
      DartSdk.dart,
      ['test'],
      workingDirectory: ormOnly.path,
    );
    expect(plain.exitCode, isNot(0));
    expect('${plain.stdout}', contains('No Ratel ORM entity manifest'));
  });

  test('ratel dev runs an ORM-only script again after each change', () async {
    final (_, output) = await start(['dev'], ormOnly);
    await waitFor(
      () async => '$output'.contains('exited with code 0'),
      output,
    );
    for (final line in scriptOutput) {
      expect('$output', contains(line));
    }

    final main = File(p.join(ormOnly.path, 'bin', 'main.dart'));
    final original = main.readAsStringSync();
    addTearDown(() => main.writeAsStringSync(original));
    main.writeAsStringSync(original.replaceFirst(
      "stdout.writeln('remaining",
      "stdout.writeln('changed');\n    stdout.writeln('remaining",
    ));
    await waitFor(
      () async => 'exited with code 0'.allMatches('$output').length == 2,
      output,
    );
    expect('$output', contains('changed\n'));
  });

  test('ratel dev serves users CRUD over SQLite with both runtimes', () async {
    final port = await CliHarness.freePort();
    final (_, output) =
        await start(['dev'], ormApp, environment: {'PORT': '$port'});
    await waitFor(
      () async => (await CliHarness.get(port, '/users'))?.$1 == 200,
      output,
    );

    final (created, createdBody) = await send(port, 'POST', '/users', {
      'email': 'ada@example.com',
      'name': 'Ada',
      'role': 'admin',
    });
    expect(created, HttpStatus.created, reason: createdBody);
    final user = jsonDecode(createdBody) as Map<String, Object?>;
    final id = user['id'];
    expect(id, isA<int>());
    expect(user, containsPair('email', 'ada@example.com'));
    expect(user, containsPair('role', 'admin'));
    expect(DateTime.parse(user['createdAt'] as String).isUtc, isTrue);

    final (found, foundBody) = await send(port, 'GET', '/users/$id');
    expect(found, HttpStatus.ok, reason: foundBody);
    expect(jsonDecode(foundBody), user);

    final (replaced, replacedBody) = await send(port, 'PUT', '/users/$id', {
      'email': 'ada@lovelace.dev',
      'name': 'Ada Lovelace',
    });
    expect(replaced, HttpStatus.ok, reason: replacedBody);
    expect(jsonDecode(replacedBody), {
      ...user,
      'email': 'ada@lovelace.dev',
      'name': 'Ada Lovelace',
      'role': 'member',
    });

    final (listed, listedBody) = await send(port, 'GET', '/users');
    expect(listed, HttpStatus.ok, reason: listedBody);
    expect(jsonDecode(listedBody), [jsonDecode(replacedBody)]);

    final (deleted, deletedBody) = await send(port, 'DELETE', '/users/$id');
    expect(deleted, HttpStatus.noContent, reason: deletedBody);
    expect(deletedBody, isEmpty);

    expect((await send(port, 'GET', '/users/$id')).$1, HttpStatus.notFound);
    expect(
      (await send(port, 'DELETE', '/users/$id')).$1,
      HttpStatus.notFound,
    );
  });

  test('every RatelCluster isolate maps entities', () async {
    final port = await CliHarness.freePort();
    final (_, output) = await start(
      ['dev', 'bin/cluster.dart'],
      ormApp,
      environment: {'PORT': '$port'},
    );
    await waitFor(
      () async =>
          'mapped node@example.com #1'.allMatches('$output').length == 2 &&
          (await CliHarness.get(port, '/users'))?.$1 == 200,
      output,
    );
    final (_, body) = (await CliHarness.get(port, '/users'))!;
    expect(jsonDecode(body), [containsPair('email', 'node@example.com')]);
    expect('$output', isNot(contains('No Ratel ORM entity manifest')));
  });
}
