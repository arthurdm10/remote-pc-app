import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CmdErrorCode {
  static const PermissionDenied = 0x0A;
  static const InvalidArguments = 0x0B;
}

enum WsConnectionStatus { unintialized, connecting, connected, error, closed }

class WebSocketProvider extends ChangeNotifier {
  WebSocketChannel conn;

  String initialDir;

  WsConnectionStatus _connectionStatus = WsConnectionStatus.unintialized;
  WsConnectionStatus get connectionStatus => _connectionStatus;

  final Map<String, CmdResponse> _cmdResponse = {
    "initial_dir": CmdResponse(),
    "ls_dir": CmdResponse(),
    "create_file": CmdResponse(),
    "delete_file": CmdResponse(),
    "rename_file": CmdResponse(),
    "download_file": CmdResponse(),
    "ls_ps": CmdResponse(),
    "kill_ps": CmdResponse(),
    "create_dir": CmdResponse(),
  };

  WebSocketProvider(Map conncectionData) {
    _connectionStatus = WsConnectionStatus.connecting;
    WebSocket.connect(
      'ws://${conncectionData["remote_server"]}/access/${conncectionData["key"]}',
      headers: {
        "X-username": conncectionData["username"],
        "X-password": conncectionData["password"]
      },
    ).then((ws) {
      ws.pingInterval = Duration(seconds: 2);
      _connectionStatus = WsConnectionStatus.connected;

      notifyListeners();

      conn = IOWebSocketChannel(ws);

      conn.stream.listen((data) {
        if (data is String) {
          final Map jsonData = jsonDecode(data);
          if (jsonData.containsKey("cmd_response")) {
            final String cmd = jsonData["cmd_response"];
            _cmdResponse[cmd].setData(jsonData);
          }
        } else if (data is List<int>) {
          _cmdResponse["download_file"].setData(data);
        }
      }, onError: (err) {
        print("Websocket connection closed: ${err.inner}");
        _connectionStatus = WsConnectionStatus.error;
        notifyListeners();
      }, onDone: () {
        if (_connectionStatus != WsConnectionStatus.unintialized) {
          _connectionStatus = WsConnectionStatus.closed;
          notifyListeners();
        }
      });
    }).catchError((err) {
      _connectionStatus = WsConnectionStatus.error;
      notifyListeners();
    });
  }

  closeConnection() async {
    await conn.sink.close();
    _connectionStatus = WsConnectionStatus.unintialized;
  }

  CmdResponse getCmdResponse(String cmd) {
    return _cmdResponse[cmd];
  }

  _sendCmdRequest(String cmd, List args, {bool isStream: false}) {
    final cmdResponse = _cmdResponse[cmd];
    cmdResponse.status = CmdResponseStatus.LOADING;
    final Map request = {
      "type": "command",
      "cmd": cmd,
      "args": args,
      "stream": isStream
    };
    conn.sink.add(jsonEncode(request));
  }

  requestInitialDir() {
    _sendCmdRequest("initial_dir", []);
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
      final data = cmdResponse.error() ? cmdResponse.errorData : cmdResponse.data;
      callback(data, cmdResponse.error());
      cmdResponse.removeListener(onDone);
    };

    cmdResponse.addListener(onDone);
    _sendCmdRequest("delete_file", [filePath]);
  }

  renameFile(String filePath, String newName, Function callback) {
    final cmdResponse = _cmdResponse["rename_file"];
    VoidCallback onDone;
    onDone = () {
      final data = cmdResponse.error() ? cmdResponse.errorData : cmdResponse.data;
      callback(data, cmdResponse.error());
      cmdResponse.removeListener(onDone);
    };

    cmdResponse.addListener(onDone);
    _sendCmdRequest("rename_file", [filePath, newName]);
  }

  /// Download [filePath] from remote PC
  ///
  /// File will be saved on [localFilePath]
  ///
  /// [onProgress] is called when a chunk of data is received
  downloadFile(
    String filePath,
    Sink<List<int>> streamSink,
    Function onProgress,
    Function onDone, {
    bool screenshot = false,
  }) async {
    final cmdResponse = _cmdResponse["download_file"];
    VoidCallback onData;

    int totalReceived = 0;

    onData = () async {
      if (cmdResponse.error()) {
        cmdResponse.removeListener(onData);
        onDone(true, cmdResponse.errorData);
        return;
      }

      final data = cmdResponse.data;
      if (data is Map) {
        if (data.containsKey("size")) {
          // print('File size $fileSize');
        } else {
          // TODO: VERIFY HASH

          final canceled = data.containsKey("canceled");

          cmdResponse.removeListener(onData);
          onDone(canceled, null);
        }
      } else {
        streamSink.add(data);
        totalReceived += data.length;
        onProgress(totalReceived);
      }
    };

    cmdResponse.addListener(onData);
    _sendCmdRequest(
      "download_file",
      [filePath, screenshot],
      isStream: true,
    );
  }

  takeScreenshot(IOSink ioFile, Function onDone) {
    downloadFile(
      "",
      ioFile,
      (_) {},
      onDone,
      screenshot: true,
    );
  }

  listProcesses() => _sendCmdRequest("ls_ps", []);

  killProcess(int pid, Function callback) {
    final cmdResponse = _cmdResponse["kill_ps"];
    Function onDone;

    onDone = () {
      callback(cmdResponse.data);
      cmdResponse.removeListener(onDone);
    };

    cmdResponse.addListener(onDone);
    _sendCmdRequest("kill_ps", [pid]);
  }

  createDirectory(String path) => _sendCmdRequest("create_dir", [path]);

  cancelStream() {
    final Map request = {
      "type": "cancel_stream",
    };
    conn.sink.add(jsonEncode(request));
  }
}

enum CmdResponseStatus { LOADING, DONE, ERROR, UNINTIALIZED }

class CmdResponse<T> extends ChangeNotifier {
  T _data;
  T get data => _data;

  CommandError _error;
  CommandError get errorData => _error;

  bool error() => status == CmdResponseStatus.ERROR;

  CmdResponseStatus status = CmdResponseStatus.UNINTIALIZED;

  setData(T data) {
    if (data is Map) {
      if (data.containsKey("error_msg") && data.containsKey("error_code")) {
        _error = CommandError.fromJson(data);
        status = CmdResponseStatus.ERROR;
        notifyListeners();
        return;
      }
    }
    _data = data;
    status = CmdResponseStatus.DONE;

    notifyListeners();
  }
}

class CommandError {
  final int code;
  final String msg;
  final String command;
  CommandError(this.command, this.code, this.msg);

  factory CommandError.fromJson(Map json) {
    return CommandError(json["cmd_response"], json["error_code"], json["error_msg"]);
  }
}
