import 'dart:io';

import 'package:ratel/runtime.dart';

import '../controllers/guarded_chat_controller.dart';

abstract final class GuardedChatControllerDefinition {
  static const value = ControllerDefinition<GuardedChatController>(
    create: GuardedChatController.new,
    sockets: [
      SocketDefinition<GuardedChatController>(
        path: '/ws/open',
        parameters: _parameters,
        invoke: _greet,
      ),
      SocketDefinition<GuardedChatController>(
        path: '/ws/member',
        isProtected: true,
        parameters: _parameters,
        invoke: _greet,
      ),
      SocketDefinition<GuardedChatController>(
        path: '/ws/admin',
        isProtected: true,
        requiredRoles: ['admin'],
        parameters: _parameters,
        invoke: _greet,
      ),
    ],
  );

  static const _parameters = [
    RouteParameter(
      name: 'socket',
      location: ParameterLocation.webSocket,
      type: WebSocket,
    ),
    RouteParameter(
      name: 'ctx',
      location: ParameterLocation.context,
      type: RequestContext,
    ),
  ];

  static Object? _greet(
    GuardedChatController controller,
    List<Object?> arguments,
  ) =>
      controller.greet(
        arguments[0] as WebSocket,
        arguments[1] as RequestContext,
      );
}
