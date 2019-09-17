import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/pages/connect_page.dart';
import 'package:remote_pc/providers/websocket_provider.dart';

import 'directory_page.dart';
import 'processes_page.dart';

class MainPage extends StatefulWidget {
  final WebSocketProvider _ws;

  MainPage(this._ws);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  WebSocketProvider ws;
  VoidCallback connectionListener;

  @override
  void initState() {
    ws = widget._ws;
    connectionListener = () {
      if (ws.connectionStatus == WsConnectionStatus.closed) {
        ws.removeListener(connectionListener);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ConnectPage(),
          ),
        );
        showDialog(
          context: context,
          builder: (_) {
            return AlertDialog(
              content: Text("Connection lost"),
            );
          },
        );
      }
    };
    ws.addListener(connectionListener);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote PC',
      home: ChangeNotifierProvider.value(
        value: ws,
        child: PageView(
          children: <Widget>[
            DirectoryPage("/home/frost"),
            ProcessesPage(),
          ],
        ),
      ),
    );
  }
}
