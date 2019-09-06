import 'package:flutter/material.dart';
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

class _DirectoryPageState extends State<DirectoryPage> {
  String _dir;
  List _dirStack = List<String>();
  WebSocketProvider _ws;
  String _searchText;
  SortFilesBy _sortFilesBy = SortFilesBy.NAME;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
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
                                  _dirStack.add(_dir);
                                  _dir = fileInfo.path;
                                  _searchText = "";
                                  _inputController.text = "";
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
