import 'package:ratel/ratel.dart';

import 'segment.dart';

@Controller('/segments')
class SegmentController {
  @Get('/current')
  Future<Segment> current() async => const Segment((0, 10));
}
