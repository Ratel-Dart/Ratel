import 'package:ratel_hygiene/src/snake_case.dart';
import 'package:test/test.dart';

void main() {
  test('converts type names the way the files are named', () {
    expect(SnakeCase.of('RatelCliRunner'), 'ratel_cli_runner');
    expect(SnakeCase.of('OpenApiSpec'), 'open_api_spec');
    expect(SnakeCase.of('HTTPServer'), 'http_server');
    expect(SnakeCase.of('Sha256Digest'), 'sha256_digest');
    expect(SnakeCase.of('Route'), 'route');
  });
}
