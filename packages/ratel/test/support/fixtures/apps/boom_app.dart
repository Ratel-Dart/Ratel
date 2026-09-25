import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';

import '../../http_probe.dart';
import '../definitions/boom_controller_definition.dart';

Future<void> main() async {
  final server = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(controllers: [BoomControllerDefinition.value]),
    ),
  );
  await server.startServer();
  final (_, body) = await HttpProbe(server.boundPort!).send('GET', '/boom');
  stdout.writeln(body);
  await server.stop(force: true);
}
