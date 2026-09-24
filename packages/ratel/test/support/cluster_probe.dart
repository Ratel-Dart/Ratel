import 'dart:io';
import 'dart:isolate';

import 'package:ratel/ratel.dart';

abstract final class ClusterProbe {
  static void record(List<String> args) {
    final routes = RatelRegistry.installed().routes.length;
    File('${args.single}${Platform.pathSeparator}${Isolate.current.hashCode}')
        .writeAsStringSync('$routes');
  }
}
