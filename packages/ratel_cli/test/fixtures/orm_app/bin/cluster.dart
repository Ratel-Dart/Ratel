import 'package:orm_app/cluster/cluster_node.dart';
import 'package:ratel/ratel.dart';

Future<void> main(List<String> args) =>
    RatelCluster.run(ClusterNode.start, isolates: 2, args: args);
