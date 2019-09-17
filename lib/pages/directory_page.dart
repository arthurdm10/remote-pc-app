import 'dart:io';

import 'package:downloads_path_provider/downloads_path_provider.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/models/file_info_model.dart';
import 'package:remote_pc/pages/components/file_options.dart';
import 'package:remote_pc/providers/websocket_provider.dart';
import 'package:remote_pc/utils.dart';

enum SortFilesBy { NAME, SIZE, DIR }

class DirectoryPage extends StatefulWidget {
  final String _dir;
  const DirectoryPage(this._dir, {Key key}) : super(key: key);

  @override
  _DirectoryPageState createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage>
    with AutomaticKeepAliveClientMixin {
  String _dir;
  List _dirStack = List<String>();
  WebSocketProvider _ws;
  String _searchText;
  SortFilesBy _sortFilesBy = SortFilesBy.NAME;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    _dir = widget._dir;
    _ws = Provider.of<WebSocketProvider>(context, listen: false);
    _ws.listDir(_dir);
    _inputController.addListener(_onSearchInputChanged);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ChangeNotifierProvider(
      builder: (_) => _ws.getCmdResponse("ls_dir"),
      child: Builder(
        builder: (context) {
          return Consumer<CmdResponse>(
            builder: (context, CmdResponse cmdResponse, _) {
              if (cmdResponse.status == CmdResponseStatus.LOADING) {
                return Center(child: CircularProgressIndicator());
              }

              if (cmdResponse.error()) {
                cmdResponse.status = CmdResponseStatus.DONE;
                if (_dirStack.isNotEmpty) {
                  _dir = _dirStack.removeLast();
                }
                Future.delayed(
                  Duration(milliseconds: 200),
                  () => showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text("Error"),
                        content: Text(cmdResponse.errorData.msg),
                      );
                    },
                  ),
                );
              }
              final cmdData = cmdResponse.data;

              if (cmdData == null || !cmdData.containsKey("response")) {
                print("No data was received");
                return Container(child: Center(child: Text("Error")));
              }

              final files = cmdResponse.data["response"].where((file) {
                if (_searchText == null || _searchText.isEmpty) {
                  return true;
                }
                return file["name"]
                    .toString()
                    .toLowerCase()
                    .contains(_searchText.toLowerCase());
              }).toList();

              return WillPopScope(
                onWillPop: () async {
                  if (_dirStack.isEmpty) {
                    return true;
                  }

                  final prevDir = _dirStack.removeLast();
                  _dir = prevDir;
                  _searchText = "";
                  _inputController.text = "";
                  _ws.listDir(prevDir);
                  return false;
                },
                child: Scaffold(
                  key: _scaffoldKey,
                  appBar: AppBar(
                    title: Text(_dir),
                    actions: <Widget>[
                      IconButton(
                        icon: Icon(Icons.photo_size_select_small),
                        tooltip: "Take a screenshot",
                        onPressed: () async {
                          final downloadsPath =
                              await DownloadsPathProvider.downloadsDirectory;
                          final fileName = '${downloadsPath.path}/screenshot.jpeg';
                          final file = File(fileName);
                          final ioFile = file.openWrite();

                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                _ws.takeScreenshot(ioFile, (canceled, error) async {
                                  await ioFile.flush();
                                  await ioFile.close();
                                  Navigator.of(context).pop();

                                  if (!canceled) {
                                    final result = await OpenFile.open(fileName);
                                    if (result != "done") {
                                      _scaffoldKey.currentState
                                          .showSnackBar(SnackBar(
                                        content: Text(result),
                                      ));
                                    }
                                  } else {
                                    final msg = canceled
                                        ? "Download canceled!"
                                        : "Download completed!";
                                    _scaffoldKey.currentState.showSnackBar(SnackBar(
                                      content: Text(msg),
                                      duration: Duration(seconds: 2),
                                    ));

                                    if (canceled) {
                                      print(
                                          "Download canceled by user... Deleting file");
                                      file.deleteSync();
                                    }
                                  }
                                });
                                return Container(
                                  width: 300,
                                  height: 350,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              });
                        },
                      ),
                      PopupMenuButton<SortFilesBy>(
                        onSelected: (SortFilesBy result) {
                          setState(() {
                            _sortFilesBy = result;
                          });
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<SortFilesBy>>[
                          PopupMenuItem<SortFilesBy>(
                            value: SortFilesBy.NAME,
                            child: Text('Sort files by name',
                                style: TextStyle(
                                    color: _sortFilesBy == SortFilesBy.NAME
                                        ? Colors.blue
                                        : Colors.black)),
                          ),
                          PopupMenuItem<SortFilesBy>(
                            value: SortFilesBy.SIZE,
                            child: Text('Sort files by size',
                                style: TextStyle(
                                    color: _sortFilesBy == SortFilesBy.SIZE
                                        ? Colors.blue
                                        : Colors.black)),
                          ),
                          PopupMenuItem<SortFilesBy>(
                            value: SortFilesBy.DIR,
                            child: Text('Sort files by directory',
                                style: TextStyle(
                                    color: _sortFilesBy == SortFilesBy.DIR
                                        ? Colors.blue
                                        : Colors.black)),
                          ),
                        ],
                      )
                    ],
                  ),
                  bottomNavigationBar: BottomAppBar(
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          IconButton(
                            icon: Icon(Icons.create_new_folder, color: Colors.blue),
                            tooltip: "Create new directory",
                            onPressed: () async {
                              final String dirName = await showDialog(
                                context: context,
                                builder: (context) {
                                  final textController = TextEditingController();
                                  return AlertDialog(
                                    title: Text("Create directory"),
                                    content: TextField(
                                      controller: textController,
                                    ),
                                    actions: <Widget>[
                                      FlatButton(
                                        child: Text("Create"),
                                        onPressed: () {
                                          final dirName = textController.text.trim();

                                          if (dirName.isEmpty ||
                                              dirName == "." ||
                                              dirName == ".." ||
                                              dirName.contains("../")) {
                                            //todo
                                          } else {
                                            Navigator.of(context).pop(dirName);
                                          }
                                        },
                                      )
                                    ],
                                  );
                                },
                              );

                              if (dirName != null && dirName.isNotEmpty) {
                                final cmdResponse = _ws.getCmdResponse("create_dir");
                                final dirPath = _dir + '/$dirName';
                                VoidCallback onResponse;
                                onResponse = () {
                                  _scaffoldKey.currentState.showSnackBar(
                                    SnackBar(
                                      content: Text(cmdResponse.error()
                                          ? cmdResponse.errorData.msg
                                          : "Directory created!"),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  cmdResponse.removeListener(onResponse);
                                };
                                cmdResponse.addListener(onResponse);
                                _ws.createDirectory(dirPath);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.file_upload, color: Colors.blue),
                            tooltip: "Upload a file",
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  body: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18.0,
                          vertical: 8.0,
                        ),
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(hintText: "Search..."),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: sortFilesList(files, _sortFilesBy).map<Widget>(
                            (fileInfoJson) {
                              final fileInfo = FileInfo.fromJson(_dir, fileInfoJson);

                              return ListTile(
                                title: Text(fileInfo.name),
                                leading: Icon(
                                  fileInfo.isDir
                                      ? Icons.folder
                                      : Icons.insert_drive_file,
                                  color:
                                      fileInfo.isDir ? Colors.blue : Colors.blueGrey,
                                ),
                                trailing: Text(fileSizeFormated(fileInfo.size)),
                                onTap: () async {
                                  if (!fileInfo.isDir) {
                                    _showFileInfoDialog(fileInfo);
                                    return;
                                  }
                                  _searchText = "";
                                  _inputController.text = "";
                                  _dirStack.add(_dir);
                                  _dir = fileInfo.path;
                                  _ws.listDir(_dir);
                                },
                                onLongPress: () => _showFileInfoDialog(fileInfo),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  _showFileInfoDialog(FileInfo fileInfo) async {
    final shouldUpdate = await showDialog(
      context: context,
      builder: (context) {
        return Provider.value(
          value: _ws,
          child: FileOptionsDialog(fileInfo, _scaffoldKey),
        );
      },
    );

    if (shouldUpdate != null && shouldUpdate) {
      _ws.listDir(_dir);
    }
  }

  _onSearchInputChanged() {
    setState(() {
      _searchText = _inputController.text;
    });
  }

  List sortFilesList(List files, SortFilesBy sortBy) {
    files.sort((f1, f2) {
      switch (sortBy) {
        case SortFilesBy.SIZE:
          return f2["size"].compareTo(f1["size"]);
        case SortFilesBy.DIR:
          // ??????
          if (f2["is_dir"]) {
            return f1["is_dir"] ? 0 : 2;
          } else {
            return f2["is_dir"] ? 2 : 0;
          }
          break;
        default:
          return f1["name"].compareTo(f2["name"]);
      }
    });
    return files;
  }
}
