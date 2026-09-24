import 'controller_definition.dart';
import 'json_codec_definition.dart';

final class RatelManifest {
  const RatelManifest({
    this.controllers = const [],
    this.jsonCodecs = const [],
    this.isolateSetup = const [],
  });

  final List<ControllerDefinition<Object>> controllers;
  final List<JsonCodecDefinition<Object>> jsonCodecs;
  final List<void Function()> isolateSetup;
}
