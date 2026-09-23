import 'dart:io';

import 'package:ratel/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  exitCode = await RatelCliRunner().run(args);
}
