import 'package:ratel/ratel.dart';

Future<void> main() async {
  await RatelServer(port: 0).startServer();
}
