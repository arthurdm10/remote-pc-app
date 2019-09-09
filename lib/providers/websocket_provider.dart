import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:crypto/crypto.dart';

class WebSocketProvider {
  WebSocketChannel conn;
  final Map<String, CmdResponse> _cmdResponse = {
    "ls_dir": CmdResponse("ls_dir"),
    "create_file": CmdResponse("create_file"),
    "delete_file": CmdResponse("delete_file"),
    "rename_file": CmdResponse("rename_file"),
    "upload_file": CmdResponse("download_file"),
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
      if (data is String) {
        final Map jsonData = jsonDecode(data);
        print('receiveid text msg: $jsonData');
        if (jsonData.containsKey("cmd_response")) {
          final String cmd = jsonData["cmd_response"];
          _cmdResponse[cmd].setData(jsonData);
        }
      } else if (data is List<int>) {
        // download_file is the only command that receives binary data
        _cmdResponse["upload_file"].setData(data);
      }
    });
  }

  CmdResponse getCmdResponse(String cmd) {
    return _cmdResponse[cmd];
  }

  _sendCmdRequest(String cmd, List<String> args, {bool isStream: false}) {
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

  renameFile(String filePath, String newName, Function callback) {
    final cmdResponse = _cmdResponse["rename_file"];
    VoidCallback onDone;
    onDone = () {
      callback(cmdResponse.data);
      cmdResponse.removeListener(onDone);
    };

    cmdResponse.addListener(onDone);
    _sendCmdRequest("rename_file", [filePath, newName]);
  }

  /// Download [filePath] from remote PC
  ///
  /// File will be saved on [localFilePath]
  /// [onProgress] is called when data is received
  downloadFile(String filePath, Sink<List<int>> streamSink, Function onProgress,
      Function onDone) async {
    final cmdResponse = _cmdResponse["upload_file"];
    VoidCallback onData;

    int fileSize = 0;
    int totalReceived = 0;

    onData = () async {
      final data = cmdResponse.data;
      if (data is Map) {
        if (data.containsKey("size")) {
          fileSize = data["size"];
          print('File size $fileSize');
        } else {
          // TODO: VERIFY HASH

          // was the download canceled?
          final canceled = data.containsKey("canceled");

          cmdResponse.removeListener(onData);
          onDone(canceled);
        }
      } else {
        streamSink.add(data);
        totalReceived += data.length;
        onProgress(totalReceived);
      }
    };

    cmdResponse.addListener(onData);
    _sendCmdRequest("upload_file", [filePath], isStream: true);
  }

  cancelStream() {
    final Map request = {
      "type": "cancel_stream",
    };
    conn.sink.add(jsonEncode(request));
  }
}

enum CmdResponseStatus { LOADING, DONE, UNINTIALIZED }

class CmdResponse<T> extends ChangeNotifier {
  T _data;
  T get data => _data;

  CmdResponseStatus status = CmdResponseStatus.UNINTIALIZED;
  String cmd;

  CmdResponse(this.cmd);

  setData(T data, [bool notify = true]) {
    _data = data;
    status = CmdResponseStatus.DONE;

    if (notify) {
      notifyListeners();
    }
  }
}

// class FileDownloadResponse extends CmdResponse<List<int>> {

//   FileDownloadResponse(): super("download_file");

//   appendData()

// }
