import 'package:ratel/ratel.dart';

import 'shape.dart';

@Controller('/shapes')
class ShapeController {
  @Get('/latest')
  Future<Shape> latest() async => throw const NotFoundException();
}
