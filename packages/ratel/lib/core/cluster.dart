import '../src/server/ratel_cluster.dart';

Future<void> runCluster(
  void Function(List<String> args) entryPoint, {
  int? isolates,
  List<String> args = const [],
}) =>
    RatelCluster.run(entryPoint, isolates: isolates, args: args);
