import 'package:ratel/ratel.dart';

import '../controllers/injected_greeting_controller.dart';
import '../models/greeting_service.dart';

final class InjectedGreetingBindings extends Bindings {
  @override
  void dependencies() {
    Injector().put<GreetingService>(() => GreetingService('injected'));
    Injector().put<InjectedGreetingController>(
      () => InjectedGreetingController(Injector().get<GreetingService>()),
    );
  }
}
