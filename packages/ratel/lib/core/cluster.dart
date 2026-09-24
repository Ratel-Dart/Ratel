import 'dart:io';
import 'dart:isolate';

Future<void> runCluster(
  void Function(List<String> args) entryPoint, {
  int? isolates,
  List<String> args = const [],
}) async {
  final count = (isolates == null || isolates <= 0)
      ? Platform.numberOfProcessors
      : isolates;
  for (var i = 1; i < count; i++) {
    await Isolate.spawn(entryPoint, args);
  }
  entryPoint(args);
}
