import 'dart:io';

import 'package:ratel/ratel.dart';

import '../models/item.dart';

@Controller('/items')
@Protected(roles: ['admin'])
class ItemsController {
  @Public()
  @Get('/:id')
  Future<Response> byId(@PathParam('id') int id, @Param() String? view) async =>
      Response.json(data: {'id': id, 'view': view});

  @Public()
  @Get('/')
  Future<Response> search(
    @Header('X-Trace') String? trace,
    @CookieParam('session') String? session,
    RequestContext ctx,
  ) async =>
      Response.json(
        data: {'trace': trace, 'session': session, 'path': ctx.path},
      );

  @Public()
  @Post('/')
  Future<Response> create(@Body() Item item) async =>
      Response.json(statusCode: 201, data: item);

  @Public()
  @Post('/upload')
  Future<Response> upload(MultipartData form, @Body() Item item) async =>
      Response.json(data: {'files': form.files.length, 'name': item.name});

  @Get('/admin/secret')
  Future<Response> secret() async => Response.json(data: {'secret': true});

  @Public()
  @Socket('/ws')
  Future<void> chat(WebSocket socket, RequestContext ctx) async {
    socket.add('hello ${ctx.path}');
    await socket.close();
  }

  @Socket('/admin/ws')
  Future<void> adminChat(WebSocket socket) async {
    socket.add('admin');
    await socket.close();
  }

  @Protected()
  @Socket('/member/ws')
  Future<void> memberChat(WebSocket socket) async {
    socket.add('member');
    await socket.close();
  }
}
