import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FakePostgresServer {
  FakePostgresServer._(this._server, this._failing);

  final ServerSocket _server;

  final Set<String> _failing;

  final List<Socket> _sockets = [];

  final List<String> statements = [];

  int get port => _server.port;

  static Future<FakePostgresServer> start({
    Set<String> failing = const {},
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakePostgresServer._(server, failing);
    server.listen(fake._serve);
    return fake;
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }

  void _serve(Socket socket) {
    _sockets.add(socket);
    var pending = Uint8List(0);
    var started = false;
    socket.listen(
      (data) {
        pending = Uint8List.fromList([...pending, ...data]);
        while (true) {
          final header = started ? 5 : 4;
          if (pending.length < header) return;
          final length = ByteData.sublistView(pending).getUint32(header - 4);
          final total = length + header - 4;
          if (pending.length < total) return;
          final type = started ? pending[0] : 0;
          final body = pending.sublist(header, total);
          pending = pending.sublist(total);
          if (!started) {
            started = true;
            _send(socket, 'R', [0, 0, 0, 0]);
            _ready(socket, 'I');
          } else {
            _handle(socket, type, body);
          }
        }
      },
      onError: (Object _) => socket.destroy(),
      onDone: socket.destroy,
    );
  }

  void _handle(Socket socket, int type, Uint8List body) {
    if (type == 'X'.codeUnitAt(0)) {
      socket.destroy();
      return;
    }
    if (type != 'Q'.codeUnitAt(0)) return;
    final statement = utf8
        .decode(body.sublist(0, body.length - 1))
        .trim()
        .replaceAll(RegExp(r';$'), '');
    statements.add(statement);
    if (_failing.contains(statement)) {
      _send(socket, 'E', [
        ..._field('S', 'ERROR'),
        ..._field('V', 'ERROR'),
        ..._field('C', 'XX000'),
        ..._field('M', 'fake failure of $statement'),
        0,
      ]);
      _ready(socket, statement == 'BEGIN' ? 'I' : 'E');
      return;
    }
    _send(socket, 'C', [...utf8.encode(statement.split(' ').first), 0]);
    _ready(socket, statement == 'BEGIN' ? 'T' : 'I');
  }

  static List<int> _field(String code, String value) =>
      [code.codeUnitAt(0), ...utf8.encode(value), 0];

  static void _ready(Socket socket, String status) =>
      _send(socket, 'Z', [status.codeUnitAt(0)]);

  static void _send(Socket socket, String type, List<int> payload) {
    final length = ByteData(4)..setUint32(0, payload.length + 4);
    socket.add([
      type.codeUnitAt(0),
      ...length.buffer.asUint8List(),
      ...payload,
    ]);
  }
}
