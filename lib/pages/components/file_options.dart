import 'dart:async';
import 'dart:io';

import 'package:downloads_path_provider/downloads_path_provider.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/models/file_info_model.dart';
import 'dart:math' as math;

import 'package:remote_pc/providers/websocket_provider.dart';
import 'package:remote_pc/utils.dart';

class FileOptionsDialog extends StatelessWidget {
  final FileInfo _fileInfo;

  final GlobalKey<ScaffoldState> _scaffoldKey;

  const FileOptionsDialog(this._fileInfo, this._scaffoldKey, {Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ws = Provider.of<WebSocketProvider>(context);

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Path: ${_fileInfo.path}'),
                Text(
                    'Size: ${fileSizeFormated(_fileInfo.size)}  (${_fileInfo.size} bytes)'),
              ],
            ),
          ),
          ListTile(
            title: Text("Open"),
            onTap: () {
              _downloadFile(ws, context, true);
            },
          ),
          ListTile(
            title: Text("Delete"),
            onTap: () async {
              final delete = await showDialog(
                  context: context,
                  builder: (_) {
                    return AlertDialog(
                      title: Text('Delete file "${_fileInfo.name}"'),
                      content: Text('Are you sure ?'),
                      actions: <Widget>[
                        FlatButton(
                          child: Text("YES"),
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                        )
                      ],
                    );
                  });
              if (delete) {
                ws.deleteFile(_fileInfo.path, (response, error) {
                  String msg;

                  if (error) {
                    msg = response.msg;
                  } else {
                    msg = response["response"];
                  }

                  _scaffoldKey.currentState.showSnackBar(SnackBar(
                    content: Text(msg),
                    duration: Duration(seconds: 2),
                  ));
                  Navigator.of(context).pop(true);
                });
              }
            },
          ),
          ListTile(
            title: Text("Rename"),
            onTap: () async {
              final String newName = await showDialog(
                context: context,
                builder: (context) {
                  final textController = TextEditingController(text: _fileInfo.name);
                  return AlertDialog(
                    title: Text("Rename file"),
                    content: TextField(
                      controller: textController,
                    ),
                    actions: <Widget>[
                      FlatButton(
                        child: Text("Rename"),
                        onPressed: () {
                          Navigator.of(context).pop(textController.text);
                        },
                      )
                    ],
                  );
                },
              );

              if (newName != null) {
                if (newName != _fileInfo.name) {
                  print(_fileInfo.path.replaceFirst(_fileInfo.name, newName));
                  ws.renameFile(_fileInfo.path,
                      _fileInfo.path.replaceFirst(_fileInfo.name, newName),
                      (response) {
                    if (response["response"]) {
                      Navigator.of(context).pop(true);
                    } else {
                      _scaffoldKey.currentState.showSnackBar(SnackBar(
                        content: Text(response["error"]),
                      ));
                    }
                  });
                }
              }
            },
          ),
          _fileInfo.isDir
              ? null
              : ListTile(
                  title: Text("Download"),
                  onTap: () {
                    _downloadFile(ws, context);
                  },
                ),
        ].where((obj) => obj != null).toList(),
      ),
    );
  }

  void _downloadFile(WebSocketProvider ws, BuildContext context,
      [bool open = false]) async {
    ValueNotifier<double> valueNotifier = ValueNotifier<double>(0.0);
    final downloadsPath = await DownloadsPathProvider.downloadsDirectory;
    final fileName = '${downloadsPath.path}/${_fileInfo.name}';

    final file = File(fileName);
    final ioFile = file.openWrite();

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return DownloadProgressDialog(
            ws,
            valueNotifier: valueNotifier,
            fileInfo: _fileInfo,
          );
        });
    ws.downloadFile(
      _fileInfo.path,
      ioFile,
      (int totalReceived) {
        valueNotifier.value = totalReceived.toDouble();
      },
      (bool canceled, CommandError error) async {
        await ioFile.flush();
        await ioFile.close();
        Navigator.of(context).pop();

        if (open && !canceled) {
          final result = await OpenFile.open(fileName);
          if (result != "done") {
            _scaffoldKey.currentState.showSnackBar(SnackBar(
              content: Text(result),
            ));
          }
        } else {
          String msg;

          if (error == null) {
            msg = canceled ? "Download canceled!" : "Download completed!";
          } else {
            msg = 'Error: ${error.msg}';
          }
          _scaffoldKey.currentState.showSnackBar(SnackBar(
            content: Text(msg),
            duration: Duration(seconds: 2),
            action: canceled || error != null
                ? null
                : SnackBarAction(
                    label: "Open",
                    onPressed: () async {
                      await OpenFile.open(fileName);
                    },
                  ),
          ));

          if (canceled) {
            print("Download canceled by user... Deleting file");
            file.deleteSync();
          }
        }
      },
    );
  }
}

class DownloadProgressDialog extends StatelessWidget {
  const DownloadProgressDialog(
    this._ws, {
    Key key,
    @required this.valueNotifier,
    @required FileInfo fileInfo,
  })  : _fileInfo = fileInfo,
        super(key: key);

  final ValueNotifier<double> valueNotifier;
  final FileInfo _fileInfo;
  final WebSocketProvider _ws;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 15),
        child: ValueListenableBuilder<double>(
          valueListenable: valueNotifier,
          builder: (context, value, _) {
            final percent = value / _fileInfo.size;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${(percent * 100).toStringAsFixed(2)} %',
                  style: TextStyle(fontSize: 18),
                ),
                LinearProgressIndicator(value: percent),
                FlatButton(
                  color: Colors.blue,
                  textColor: Colors.white,
                  child: Text("Cancel"),
                  onPressed: () {
                    _ws.cancelStream();
                  },
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
