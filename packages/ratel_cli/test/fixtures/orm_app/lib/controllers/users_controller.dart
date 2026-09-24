import 'dart:io';

import 'package:ratel/ratel.dart';

import '../dtos/user_input.dart';
import '../entities/user.dart';
import '../repositories/user_repository.dart';

@Controller('/users')
class UsersController {
  UsersController(this.users);

  final UserRepository users;

  @Get('/')
  Future<List<User>> list() => users.findAll();

  @Get('/:id')
  Future<User> byId(@PathParam('id') int id) async =>
      await users.findById(id) ?? (throw const NotFoundException());

  @Post('/')
  Future<Response<User>> create(@Body() UserInput input) async {
    final user = await users.insert(User(
      email: input.email,
      name: input.name,
      role: input.role,
      createdAt: DateTime.now().toUtc(),
    ));
    return Response.json(statusCode: HttpStatus.created, data: user);
  }

  @Put('/:id')
  Future<User> replace(
    @PathParam('id') int id,
    @Body() UserInput input,
  ) async {
    final current =
        await users.findById(id) ?? (throw const NotFoundException());
    final updated = await users.update(User(
      id: id,
      email: input.email,
      name: input.name,
      role: input.role,
      createdAt: current.createdAt,
    ));
    return updated ?? (throw const NotFoundException());
  }

  @Delete('/:id')
  Future<Response> remove(@PathParam('id') int id) async {
    if (!await users.deleteById(id)) throw const NotFoundException();
    return Response(statusCode: HttpStatus.noContent);
  }
}
