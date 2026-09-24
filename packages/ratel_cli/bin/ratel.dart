import 'dart:io';

import 'package:ratel_cli/ratel_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await RatelCliRunner().run(args);
}
