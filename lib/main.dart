import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qrcode_reader/qrcode_reader.dart';
import 'package:remote_pc/pages/directory_page.dart';
import 'package:remote_pc/pages/processes_page.dart';
import 'package:remote_pc/providers/websocket_provider.dart';

void main() => runApp(ConnectPage());

class MainPage extends StatefulWidget {
  final Map connectionData;

  MainPage(this.connectionData);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // final pcKey = "key123";

  WebSocketProvider ws;

  @override
  void initState() {
    ws = WebSocketProvider(
        widget.connectionData["remote_server"], widget.connectionData["key"]);
    // final ws = WebSocketProvider("192.168.0.110", 9002, pcKey);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material App',
      home: MultiProvider(
        providers: [
          Provider.value(value: ws),
        ],
        child: PageView(
          children: <Widget>[
            DirectoryPage("/home/frost/"),
            ProcessesPage(),
          ],
        ),
      ),
    );
  }
}

class ConnectPage extends StatelessWidget {
  const ConnectPage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("Connect"),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final codeData = await QRCodeReader()
                  .setAutoFocusIntervalInMs(200) // default 5000
                  .setForceAutoFocus(true) // default false
                  .setTorchEnabled(true) // default false
                  .setHandlePermissions(true) // default true
                  .setExecuteAfterPermissionGranted(true) // default true
                  .scan();

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => MainPage(
                    jsonDecode(codeData),
                  ),
                ),
              );

              // Navigator.of(context).pushReplacement(
              //   MaterialPageRoute(
              //     builder: (_) => MainPage(
              //       jsonDecode(
              //           '{"remote_server": "10.0.3.2:9002", "key": "key123"}'),
              //     ),
              //   ),
              // );
              // return;
            },
            child: Icon(Icons.photo_camera),
          ),
        ),
      ),
    );
  }
}
