import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/models/file_info_model.dart';
import 'dart:math' as math;

import 'package:remote_pc/providers/websocket_provider.dart';

class FileOptionsDialog extends StatelessWidget {
  final FileInfo _fileInfo;
  const FileOptionsDialog(this._fileInfo, {Key key}) : super(key: key);

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
                Text('Size: ${_fileSizeFormated()}  (${_fileInfo.size} bytes)'),
              ],
            ),
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
                ws.deleteFile(_fileInfo.path, (response) {
                  if (response["success"]) {
                    Scaffold.of(context).showSnackBar(SnackBar(
                      content: Text("File deleted!"),
                      duration: Duration(seconds: 2),
                    ));
                    Navigator.of(context).pop();
                  }
                });
              }
            },
          ),
          ListTile(
            title: Text("Rename"),
            onTap: () {},
          )
        ],
      ),
    );
  }

  String _fileSizeFormated() {
    ///https://stackoverflow.com/questions/3263892/format-file-size-as-mb-gb-etc
    final units = ["B", "kB", "MB", "GB", "TB"];
    final fileSize = _fileInfo.size;

    if (fileSize <= 0) {
      return "0 B";
    }
    final digitGroups = math.log(fileSize) ~/ math.log(1024);
    final val = fileSize / math.pow(1024, digitGroups);

    return '${val.toStringAsFixed(2)} ${units[digitGroups]}';
  }
}
