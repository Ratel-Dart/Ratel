import 'package:test/test.dart';

import 'support/generator_harness.dart';

const _imports = '''
import 'package:ratel/annotations/annotations.dart';
import 'package:ratel/http/handler.dart';
''';

const _model = '''
import 'package:ratel/annotations/annotations.dart';

@Json()
class Invoice {
  int amount = 0;
}
''';

void main() {
  test('calls the local deserializer without a prefix', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

@Json()
class Invoice {
  int amount = 0;
}

class InvoiceController extends RatelHandler {
  @Post('/invoices')
  Future<String> create(@Body() Invoice invoice) async => '';
}
''',
    });

    expect(output, contains('create(\$InvoiceFromJson(jsonBody))'));
    expect(output, isNot(contains('_m0')));
  });

  test('imports a package library by its generated package URI', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/model.dart': _model,
      'app|lib/api.dart': '''
$_imports
import 'package:app/model.dart';

class InvoiceController extends RatelHandler {
  @Post('/invoices')
  Future<String> create(@Body() Invoice invoice) async => '';
}
''',
    });

    expect(
      output,
      contains("import 'package:app/model.ratel.dart' as _m0;"),
    );
    expect(output, contains('create(_m0.\$InvoiceFromJson(jsonBody))'));
  });

  test('imports a non-package library by a relative path', () async {
    final output = await generate('app|test/api.dart', {
      'app|test/model.dart': _model,
      'app|test/api.dart': '''
$_imports
import 'model.dart';

class InvoiceController extends RatelHandler {
  @Post('/invoices')
  Future<String> create(@Body() Invoice invoice) async => '';
}
''',
    });

    expect(output, contains("import 'model.ratel.dart' as _m0;"));
    expect(output, contains('create(_m0.\$InvoiceFromJson(jsonBody))'));
  });

  test('walks up to a sibling directory for a non-package library', () async {
    final output = await generate('app|test/nested/api.dart', {
      'app|test/model.dart': _model,
      'app|test/nested/api.dart': '''
$_imports
import '../model.dart';

class InvoiceController extends RatelHandler {
  @Post('/invoices')
  Future<String> create(@Body() Invoice invoice) async => '';
}
''',
    });

    expect(output, contains("import '../model.ratel.dart' as _m0;"));
  });

  test('gives each cross-library model its own import prefix', () async {
    final output = await generate('app|lib/api.dart', {
      'app|lib/invoice.dart': _model,
      'app|lib/payment.dart': '''
import 'package:ratel/annotations/annotations.dart';

@Json()
class Payment {
  int amount = 0;
}
''',
      'app|lib/api.dart': '''
$_imports
import 'package:app/invoice.dart';
import 'package:app/payment.dart';

class BillingController extends RatelHandler {
  @Post('/invoices')
  Future<String> invoice(@Body() Invoice invoice) async => '';

  @Post('/payments')
  Future<String> payment(@Body() Payment payment) async => '';
}
''',
    });

    expect(output, contains("import 'package:app/invoice.ratel.dart' as _m0;"));
    expect(output, contains("import 'package:app/payment.ratel.dart' as _m1;"));
    expect(output, contains('_m0.\$InvoiceFromJson(jsonBody)'));
    expect(output, contains('_m1.\$PaymentFromJson(jsonBody)'));
  });

  test('rejects a @Body type that is not annotated with @Json', () async {
    final errors = await generateErrors('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class Plain {
  int amount = 0;
}

class PlainController extends RatelHandler {
  @Post('/plain')
  Future<String> create(@Body() Plain plain) async => '';
}
''',
    });

    expect(
      errors.join('\n'),
      contains('The @Body() type Plain is not annotated with @Json()'),
    );
  });

  test('rejects a @Body type with no zero-argument constructor', () async {
    final errors = await generateErrors('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

@Json()
class Ticket {
  Ticket(this.amount);

  int amount;
}

class TicketController extends RatelHandler {
  @Post('/tickets')
  Future<String> create(@Body() Ticket ticket) async => '';
}
''',
    });

    expect(
      errors.join('\n'),
      contains('The @Body() type Ticket has no zero-argument constructor'),
    );
  });

  test('rejects a @Body parameter that is not a class', () async {
    final errors = await generateErrors('app|lib/api.dart', {
      'app|lib/api.dart': '''
$_imports

class ScalarController extends RatelHandler {
  @Post('/scalar')
  Future<String> create(@Body() void Function() callback) async => '';
}
''',
    });

    expect(
      errors.join('\n'),
      contains('A @Body() parameter must be a class annotated with @Json()'),
    );
  });
}
