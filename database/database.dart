import 'package:postgres/postgres.dart';

import 'repository.dart';

class RatelDatabase {
  final String host;
  final String port;
  final String databaseName;
  final String username;
  final String password;

  RatelDatabase({
    required this.host,
    this.port = '5432',
    required this.databaseName,
    required this.username,
    required this.password,
  }) {
    RatelRepository.configure(this);
  }

  Future<Connection> connect() async {
    return await Connection.open(
      Endpoint(
        host: host,
        database: databaseName,
        username: username,
        password: password,
        port: int.tryParse(port)!,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
  }
}
