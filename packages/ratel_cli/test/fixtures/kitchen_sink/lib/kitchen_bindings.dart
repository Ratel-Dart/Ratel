import 'package:ratel/ratel.dart';

import 'controllers/greeting_controller.dart';
import 'models/greeter.dart';

class KitchenBindings extends Bindings {
  @override
  void dependencies() {
    Injector().put<GreetingController>(
      () => GreetingController(const Greeter('Ahoy')),
    );
  }
}
