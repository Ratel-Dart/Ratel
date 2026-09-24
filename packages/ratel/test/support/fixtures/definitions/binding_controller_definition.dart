import 'dart:io';

import 'package:ratel/runtime.dart';

import '../controllers/binding_controller.dart';
import '../models/greeting.dart';

abstract final class BindingControllerDefinition {
  static const value = ControllerDefinition<BindingController>(
    create: BindingController.new,
    routes: [
      RouteDefinition<BindingController>(
        method: 'GET',
        path: '/items/:id',
        parameters: [
          RouteParameter(
            name: 'id',
            location: ParameterLocation.path,
            type: int,
            isRequired: true,
          ),
          RouteParameter(
            name: 'filter',
            location: ParameterLocation.query,
            type: String,
          ),
          RouteParameter(
            name: 'X-Trace',
            location: ParameterLocation.header,
            type: String,
          ),
          RouteParameter(
            name: 'session',
            location: ParameterLocation.cookie,
            type: String,
          ),
        ],
        invoke: _item,
      ),
      RouteDefinition<BindingController>(
        method: 'GET',
        path: '/me',
        parameters: [
          RouteParameter(
            name: 'ctx',
            location: ParameterLocation.context,
            type: RequestContext,
          ),
        ],
        invoke: _me,
      ),
      RouteDefinition<BindingController>(
        method: 'POST',
        path: '/echo',
        parameters: [
          RouteParameter(
            name: 'body',
            location: ParameterLocation.body,
            type: Greeting,
            isRequired: true,
          ),
        ],
        invoke: _echo,
      ),
      RouteDefinition<BindingController>(
        method: 'POST',
        path: '/upload',
        parameters: [
          RouteParameter(
            name: 'form',
            location: ParameterLocation.multipart,
            type: MultipartData,
          ),
          RouteParameter(
            name: 'body',
            location: ParameterLocation.body,
            type: Greeting,
            isRequired: true,
          ),
        ],
        invoke: _upload,
      ),
      RouteDefinition<BindingController>(
        method: 'GET',
        path: '/plain',
        isProtected: true,
        requiredRoles: ['admin'],
        invoke: _plain,
      ),
    ],
    sockets: [
      SocketDefinition<BindingController>(
        path: '/ws',
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
        invoke: _chat,
      ),
    ],
  );

  static Object? _item(BindingController controller, List<Object?> arguments) =>
      controller.item(
        arguments[0] as int,
        arguments[1] as String?,
        arguments[2] as String?,
        arguments[3] as String?,
      );

  static Object? _me(BindingController controller, List<Object?> arguments) =>
      controller.me(arguments[0] as RequestContext);

  static Object? _echo(BindingController controller, List<Object?> arguments) =>
      controller.echo(arguments[0] as Greeting);

  static Object? _upload(
    BindingController controller,
    List<Object?> arguments,
  ) =>
      controller.upload(
        arguments[0] as MultipartData,
        arguments[1] as Greeting,
      );

  static Object? _plain(
          BindingController controller, List<Object?> arguments) =>
      controller.plain();

  static Object? _chat(BindingController controller, List<Object?> arguments) =>
      controller.chat(
        arguments[0] as WebSocket,
        arguments[1] as RequestContext,
      );
}
