import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketProvider {
  WebSocketChannel conn;

  WebSocketProvider(String remoteServer, int port, String pcKey) {
    final url =
        Uri(scheme: "ws", host: remoteServer, port: port, path: '/access/$pcKey')
            .toString();
    conn = IOWebSocketChannel.connect(url);

    // conn.stream.listen((data){

    // });
  }

  listDir(String dirPath) {
    final Map request = {
      "type": "command",
      "cmd": "ls_dir",
      "args": [dirPath]
    };
    conn.sink.add(jsonEncode(request));
  }

  createFile(String filePath) {
    final Map request = {
      "type": "command",
      "cmd": "create_file",
      "args": [filePath]
    };
    conn.sink.add(jsonEncode(request));
  }
}
