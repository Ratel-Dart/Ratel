import 'dart:io';

import 'package:ratel/runtime.dart';

import '../controllers/chat_controller.dart';

abstract final class ChatControllerDefinition {
  static const value = ControllerDefinition<ChatController>(
    create: ChatController.new,
    routes: [
      RouteDefinition<ChatController>(
        method: 'GET',
        path: '/ws',
        invoke: _describe,
      ),
    ],
    sockets: [
      SocketDefinition<ChatController>(
        path: '/ws',
        parameters: [
          RouteParameter(
            name: 'socket',
            location: ParameterLocation.webSocket,
            type: WebSocket,
          ),
        ],
        invoke: _chat,
      ),
      SocketDefinition<ChatController>(
        path: '/ws/context',
        parameters: [
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
        ],
        invoke: _withContext,
      ),
    ],
  );

  static Object? _chat(ChatController controller, List<Object?> arguments) =>
      controller.chat(arguments[0] as WebSocket);

  static Object? _withContext(
    ChatController controller,
    List<Object?> arguments,
  ) =>
      controller.withContext(
        arguments[0] as WebSocket,
        arguments[1] as RequestContext,
      );

  static Object? _describe(
    ChatController controller,
    List<Object?> arguments,
  ) =>
      controller.describe();
}
