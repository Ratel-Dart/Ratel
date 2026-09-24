import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/process/dart_sdk.dart';

final class CliHarness {
  CliHarness._(this.snapshot);

  final String snapshot;

  static const applicationControlBlocked = 4551;

  static String get packageRoot => p.normalize(p.absolute('.'));

  static String get ratelPackage =>
      p.normalize(p.join(packageRoot, '..', 'ratel'));

  static String get _runtime => p.join(
        DartSdk.root,
        'bin',
        Platform.isWindows ? 'dartaotruntime.exe' : 'dartaotruntime',
      );

  static Future<CliHarness> compile(Directory into) async {
    final output = p.join(into.path, 'ratel.aot');
    final result = await Process.run(DartSdk.dart, [
      'compile',
      'aot-snapshot',
      p.join(packageRoot, 'bin', 'ratel.dart'),
      '-o',
      output,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Could not compile the CLI:\n${result.stderr}');
    }
    return CliHarness._(output);
  }

  Future<ProcessResult> run(List<String> arguments,
          {required String workingDirectory}) =>
      Process.run(_runtime, [snapshot, ...arguments],
          workingDirectory: workingDirectory);

  Future<Process> start(
    List<String> arguments, {
    required String workingDirectory,
    Map<String, String> environment = const {},
  }) =>
      Process.start(
        _runtime,
        [snapshot, ...arguments],
        workingDirectory: workingDirectory,
        environment: environment,
      );

  Future<Directory> scaffold(Directory parent) async {
    final created =
        await run(['create', 'hello_app'], workingDirectory: parent.path);
    if (created.exitCode != 0) {
      throw StateError(
        'ratel create failed:\n${created.stdout}${created.stderr}',
      );
    }
    final app = Directory(p.join(parent.path, 'hello_app'));
    final pubspec = File(p.join(app.path, 'pubspec.yaml'));
    pubspec.writeAsStringSync(
      '${pubspec.readAsStringSync()}\n'
      'dependency_overrides:\n'
      '  ratel:\n'
      '    path: ${ratelPackage.replaceAll(r'\', '/')}\n',
    );
    final resolved = await Process.run(
      DartSdk.dart,
      ['pub', 'get', '--offline'],
      workingDirectory: app.path,
    );
    if (resolved.exitCode != 0) {
      throw StateError(
        'pub get failed:\n${resolved.stdout}${resolved.stderr}',
      );
    }
    return app;
  }

  static Future<int> freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static Future<(int, String)?> get(int port, String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
      final response = await request.close();
      return (
        response.statusCode,
        await response.transform(utf8.decoder).join(),
      );
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> until(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Condition not met within $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  static Future<void> kill(Process process, {bool tree = true}) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', [
        '/F',
        if (tree) '/T',
        '/PID',
        '${process.pid}',
      ]);
    } else {
      process.kill(ProcessSignal.sigkill);
    }
    await process.exitCode;
  }
}
