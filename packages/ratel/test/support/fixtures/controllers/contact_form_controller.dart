import 'package:ratel/ratel.dart';

import '../models/contact_form.dart';

final class ContactFormController {
  Future<Response> submit(ContactForm form) async => Response.json(
        data: {'name': form.name, 'city': form.city},
      );

  Future<Response> old() async => Response.redirect('/new', statusCode: 301);
}
