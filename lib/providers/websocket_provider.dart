import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketProvider {
  WebSocketChannel conn;
  final Map<String, CmdResponse> _cmdResponse = {
    "ls_dir": CmdResponse("ls_dir"),
    "create_file": CmdResponse("create_file"),
    "delete_file": CmdResponse("delete_file"),
  };

  WebSocketProvider(String remoteServer, int port, String pcKey) {
    final url = Uri(
      scheme: "ws",
      host: remoteServer,
      port: port,
      path: '/access/$pcKey',
    ).toString();

    conn = IOWebSocketChannel.connect(url);

    conn.stream.listen((data) {
      final Map jsonData = jsonDecode(data);

      if (jsonData.containsKey("cmd_response")) {
        final String cmd = jsonData["cmd_response"];
        _cmdResponse[cmd].setData(jsonData);
      }
    });
  }

  CmdResponse getCmdResponse(String cmd) {
    return _cmdResponse[cmd];
  }

  _sendCmdRequest(String cmd, List<String> args) {
    final cmdResponse = _cmdResponse[cmd];
    cmdResponse.status = CmdResponseStatus.LOADING;
    final Map request = {"type": "command", "cmd": cmd, "args": args};
    conn.sink.add(jsonEncode(request));
  }

  listDir(String dirPath) {
    _sendCmdRequest("ls_dir", [dirPath]);
  }

  createFile(String filePath, Function callback) {
    final cmdResponse = _cmdResponse["create_file"];
    VoidCallback onDone;
    onDone = () {
      callback(cmdResponse.data["success"]);
      cmdResponse.removeListener(onDone);
    };

    cmdResponse.addListener(onDone);
    _sendCmdRequest("create_file", [filePath]);
  }

  /// Delete [filePath]
  ///
  /// [callback] will be called with a json response
  deleteFile(String filePath, Function callback) {
    final cmdResponse = _cmdResponse["delete_file"];
    VoidCallback onDone;
    onDone = () {
      callback(cmdResponse.data);
      cmdResponse.removeListener(onDone);
    };

    cmdResponse.addListener(onDone);
    _sendCmdRequest("delete_file", [filePath]);
  }
}

enum CmdResponseStatus { LOADING, DONE, UNINTIALIZED }

class CmdResponse extends ChangeNotifier {
  Map _data;
  Map get data => _data;

  CmdResponseStatus status = CmdResponseStatus.UNINTIALIZED;
  String cmd;

  CmdResponse(this.cmd);

  setData(Map data, [bool notify = true]) {
    _data = data;
    status = CmdResponseStatus.DONE;

    if (notify) {
      notifyListeners();
    }
  }
}
