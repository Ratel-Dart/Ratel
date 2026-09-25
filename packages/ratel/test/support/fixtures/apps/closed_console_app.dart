import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/src/logging/ratel_logger.dart';

Future<void> main() async {
  final server = RatelServer(port: 0, registry: RatelRegistry());
  await server.startServer();
  stdout.writeln('listening');
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  for (var i = 0; i < 3; i++) {
    RatelLogger.instance.info('logged after stdout closed $i');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  await server.stop();
  stderr.writeln('still running');
}
