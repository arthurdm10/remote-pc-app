import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/providers/websocket_provider.dart';

class DirectoryPage extends StatefulWidget {
  final String _dir;
  const DirectoryPage(this._dir, {Key key}) : super(key: key);

  @override
  _DirectoryPageState createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  String _dir;
  Map data;
  List _dirStack = List<String>();
  WebSocketProvider _ws;

  @override
  void initState() {
    _dir = widget._dir;
    _ws = Provider.of<WebSocketProvider>(context, listen: false);
    _ws.listDir(_dir);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final wsResponse = Provider.of<String>(context);
    print("data on: " + _dir);
    if (wsResponse == null) {
      return Center(child: CircularProgressIndicator());
    }

    data = jsonDecode(wsResponse);
    if (data.containsKey("error")) {
      print(data);
      return Container(color: Colors.orange, child: Center());
    }

    return WillPopScope(
      onWillPop: () async {
        if (_dirStack.isEmpty) {
          return true;
        }

        final prevDir = _dirStack.removeLast();
        _dir = prevDir;
        _ws.listDir(prevDir);
        return false;
      },
      child: Scaffold(
          appBar: AppBar(
            title: Text(_dir),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  _ws.createFile(_dir + "/" + "filetest.txt");
                },
              )
            ],
          ),
          body: ListView(
            children: data["data"].map<Widget>(
              (fileInfo) {
                return ListTile(
                  title: Text(fileInfo["name"]),
                  leading: Icon(
                    fileInfo["is_dir"] ? Icons.folder : Icons.insert_drive_file,
                  ),
                  onTap: () async {
                    if (!fileInfo["is_dir"]) {
                      return;
                    }
                    _dirStack.add(_dir);
                    _dir = _dir + "/" + fileInfo["name"];
                    _ws.listDir(_dir);
                  },
                );
              },
            ).toList(),
          )),
    );
  }
}
