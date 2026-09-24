import 'dart:io';

import 'dart_sdk.dart';

abstract final class DartProcess {
  static Future<int> run(
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      DartSdk.dart,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}
