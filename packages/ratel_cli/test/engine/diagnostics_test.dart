import 'package:ratel_cli/src/engine/diagnostics/diagnostic_codes.dart';
import 'package:ratel_cli/src/engine/diagnostics/ratel_diagnostic.dart';
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:test/test.dart';

import '../support/engine_harness.dart';

void main() {
  late GenerationResult result;

  setUpAll(() async {
    result = await EngineHarness.generate(
      'broken_app',
      packageName: 'broken_app',
    );
  });

  RatelDiagnostic single(String code) =>
      result.diagnostics.singleWhere((diagnostic) => diagnostic.code == code);

  test('reports misplaced annotations and writes nothing', () {
    expect(result.hasErrors, isTrue);
    expect(result.files, isEmpty);
    final codes = {
      for (final diagnostic in result.diagnostics) diagnostic.code
    };
    expect(codes, contains(DiagnosticCodes.missingController));
    final orphan = single(DiagnosticCodes.missingController);
    expect(orphan.path, endsWith('orphan.dart'));
    expect(orphan.line, 5);
  });

  test('reports a route parameter without a binding annotation', () {
    final unbound = single(DiagnosticCodes.unboundParameter);
    expect(unbound.isError, isTrue);
    expect(unbound.path, endsWith('unbound_controller.dart'));
    expect(unbound.line, 6);
    expect(
      unbound.message,
      allOf([
        contains('UnboundController.show'),
        contains(' id '),
        contains('@PathParam'),
        contains('@Param'),
        contains('@Header'),
        contains('@CookieParam'),
        contains('@Body'),
      ]),
    );
  });

  test('reports a static route method', () {
    final staticRoute = single(DiagnosticCodes.staticRoute);
    expect(staticRoute.isError, isTrue);
    expect(staticRoute.path, endsWith('static_route_controller.dart'));
    expect(staticRoute.line, 6);
    expect(staticRoute.message, contains('StaticRouteController.list'));
  });

  test('reports a body that is not a class', () {
    final body = single(DiagnosticCodes.bodyNotClass);
    expect(body.isError, isTrue);
    expect(body.path, endsWith('bodies_controller.dart'));
    expect(body.line, 6);
    expect(
      body.message,
      allOf([contains('BodiesController.count'), contains('type int')]),
    );
  });

  test('reports a body DTO it cannot construct', () {
    final ticket = single(DiagnosticCodes.dtoNotConstructible);
    expect(ticket.isError, isTrue);
    expect(ticket.path, endsWith('ticket.dart'));
    expect(ticket.line, 1);
    expect(
      ticket.message,
      allOf([
        startsWith('TicketController.redeem needs Ratel to build Ticket'),
        contains('no public unnamed constructor'),
      ]),
    );
  });

  test('reports an abstract class a route returns', () {
    final shape = single(DiagnosticCodes.dtoAbstract);
    expect(shape.isError, isTrue);
    expect(shape.path, endsWith('shape_controller.dart'));
    expect(shape.line, 8);
    expect(
      shape.message,
      startsWith('ShapeController.latest uses Shape, an abstract class'),
    );
  });

  test('reports a DTO field whose type has no JSON form', () {
    final segment = single(DiagnosticCodes.dtoUnsupportedType);
    expect(segment.isError, isTrue);
    expect(segment.path, endsWith('segment.dart'));
    expect(segment.line, 4);
    expect(
      segment.message,
      startsWith('SegmentController.current -> Segment.span has type '
          '(int, int), which Ratel cannot convert to JSON'),
    );
  });

  test('reports a path parameter the route path does not declare', () {
    final unknown = single(DiagnosticCodes.unknownPathParam);
    expect(unknown.isError, isTrue);
    expect(unknown.path, endsWith('unknown_path_param_controller.dart'));
    expect(unknown.line, 6);
    expect(
      unknown.message,
      allOf([contains(':userId'), contains('GET /users/:id')]),
    );
  });
}
