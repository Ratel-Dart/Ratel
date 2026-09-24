import 'package:analyzer/dart/element/element.dart';

import 'scanned_route.dart';
import 'scanned_socket.dart';

final class ScannedController {
  const ScannedController({
    required this.element,
    required this.isConstructible,
    required this.routes,
    required this.sockets,
  });

  final ClassElement element;
  final bool isConstructible;
  final List<ScannedRoute> routes;
  final List<ScannedSocket> sockets;
}
