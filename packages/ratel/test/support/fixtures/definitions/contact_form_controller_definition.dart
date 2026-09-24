import 'package:ratel/runtime.dart';

import '../controllers/contact_form_controller.dart';
import '../models/contact_form.dart';

abstract final class ContactFormControllerDefinition {
  static const value = ControllerDefinition<ContactFormController>(
    create: ContactFormController.new,
    routes: [
      RouteDefinition<ContactFormController>(
        method: 'POST',
        path: '/submit',
        parameters: [
          RouteParameter(
            name: 'form',
            location: ParameterLocation.body,
            type: ContactForm,
            isRequired: true,
          ),
        ],
        invoke: _submit,
      ),
      RouteDefinition<ContactFormController>(
        method: 'GET',
        path: '/old',
        invoke: _old,
      ),
    ],
  );

  static Object? _submit(
    ContactFormController controller,
    List<Object?> arguments,
  ) =>
      controller.submit(arguments[0] as ContactForm);

  static Object? _old(
    ContactFormController controller,
    List<Object?> arguments,
  ) =>
      controller.old();
}
