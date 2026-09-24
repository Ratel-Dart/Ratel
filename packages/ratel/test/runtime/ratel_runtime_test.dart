import 'dart:isolate';

import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/isolate_setup_recorder.dart';

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

  test('runs the isolate setup in order, once, after installing', () async {
    final calls = await Isolate.run(() {
      RatelRuntime.install(IsolateSetupRecorder.manifest);
      RatelRuntime.install(IsolateSetupRecorder.manifest);
      return IsolateSetupRecorder.calls;
    });

    expect(calls, ['first', 'second, installed']);
  });

  test('a rejected manifest runs none of its isolate setup', () async {
    final calls = await Isolate.run(() {
      RatelRuntime.install(const RatelManifest());
      try {
        RatelRuntime.install(IsolateSetupRecorder.manifest);
      } on StateError {
        return IsolateSetupRecorder.calls;
      }
      return null;
    });

    expect(calls, <String>[]);
  });
}
