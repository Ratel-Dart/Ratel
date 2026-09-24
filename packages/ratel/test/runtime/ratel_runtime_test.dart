import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

void main() {
  test('installs a manifest once per isolate', () {
    const manifest = RatelManifest();
    expect(RatelRuntime.installed, isNull);

    RatelRuntime.install(manifest);
    RatelRuntime.install(manifest);

    expect(RatelRuntime.installed, same(manifest));
    expect(
      () => RatelRuntime.install(RatelManifest(controllers: [])),
      throwsStateError,
    );
  });
}
