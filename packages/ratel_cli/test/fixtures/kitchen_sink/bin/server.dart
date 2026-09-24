import 'dart:io';

import 'package:kitchen_sink_app/kitchen_bindings.dart';
import 'package:ratel/ratel.dart';

Future<void> main(List<String> args) async {
  final server = RatelServer(
    port: int.parse(args.first),
    jwtKey: 'kitchen-secret',
    bindings: KitchenBindings(),
  );
  await server.startServer();
  stdout.writeln('listening ${server.boundPort}');
}
