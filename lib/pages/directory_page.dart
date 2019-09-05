import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/models/file_info_model.dart';
import 'package:remote_pc/pages/components/file_options.dart';
import 'package:remote_pc/providers/websocket_provider.dart';

enum SortFilesBy { NAME, SIZE }

class DirectoryPage extends StatefulWidget {
  final String _dir;
  const DirectoryPage(this._dir, {Key key}) : super(key: key);

  @override
  _DirectoryPageState createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  String _dir;
  List _dirStack = List<String>();
  WebSocketProvider _ws;
  String _searchText;
  SortFilesBy _sortFilesBy = SortFilesBy.NAME;

  @override
  void initState() {
    _dir = widget._dir;
    _ws = Provider.of<WebSocketProvider>(context, listen: false);
    _ws.listDir(_dir);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      builder: (_) => _ws.getCmdResponse("ls_dir"),
      child: Builder(
        builder: (context) {
          return Consumer<CmdResponse>(
            builder: (context, CmdResponse cmdResponse, _) {
              if (cmdResponse.status == CmdResponseStatus.LOADING) {
                return Center(child: CircularProgressIndicator());
              }

              final files = cmdResponse.data["data"].where((file) {
                if (_searchText == null || _searchText.isEmpty) {
                  return true;
                }
                return file["name"].toString().contains(_searchText);
              }).toList();

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
                        icon: Icon(Icons.file_upload),
                        onPressed: () {},
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
                        ],
                      )
                    ],
                  ),
                  body: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18.0,
                          vertical: 8.0,
                        ),
                        child: TextField(
                          onChanged: _onSearchInputChanged,
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
                                ),
                                onTap: () async {
                                  if (!fileInfo.isDir) {
                                    return;
                                  }
                                  _dirStack.add(_dir);
                                  _dir = fileInfo.path;
                                  _ws.listDir(_dir);
                                },
                                onLongPress: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return Provider.value(
                                        value: _ws,
                                        child: FileOptionsDialog(fileInfo),
                                      );
                                    },
                                  );
                                },
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

  _onSearchInputChanged(String text) {
    setState(() {
      _searchText = text;
    });
  }

  List sortFilesList(List files, SortFilesBy sortBy) {
    files.sort((f1, f2) {
      switch (sortBy) {
        case SortFilesBy.SIZE:
          return f2["size"].compareTo(f1["size"]);
        default:
          return f2["name"].compareTo(f1["name"]);
      }
    });
    return files;
  }
}
