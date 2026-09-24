import 'dart:io';

import 'package:ratel_hygiene/ratel_hygiene.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await HygieneCommand.run(arguments);
}
