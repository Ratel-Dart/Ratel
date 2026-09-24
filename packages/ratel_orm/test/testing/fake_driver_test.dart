import 'package:ratel_orm/testing.dart';

import '../support/driver_conformance.dart';

void main() {
  DriverConformance.run(FakeDriver.new);
}
