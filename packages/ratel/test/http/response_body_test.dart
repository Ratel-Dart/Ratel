import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/response_body_controller_definition.dart';
import '../support/http_probe.dart';

void main() {
  final server = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(
        controllers: [ResponseBodyControllerDefinition.value],
      ),
    ),
  );
  late HttpProbe probe;

  setUpAll(() async {
    await server.startServer();
    probe = HttpProbe(server.boundPort!);
  });

  tearDownAll(() => server.stop(force: true));

  test('a null body with a text content type writes no body', () async {
    final (status, body) = await probe.send('GET', '/empty-text');
    expect(status, 200);
    expect(body, isEmpty);
  });

  test('a JSON content type with parameters is still JSON-encoded', () async {
    final (status, body) = await probe.send('GET', '/charset-json');
    expect(status, 200);
    expect(body, '{"ok":true}');
  });
}
