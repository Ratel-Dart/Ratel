import '../http/socket_handler.dart';

final class SocketRoute {
  SocketRoute({
    required this.path,
    required this.handler,
    this.isProtected = false,
    this.requiredRoles = const [],
  });

  final String path;
  final SocketHandler handler;
  final bool isProtected;
  final List<String> requiredRoles;
}
