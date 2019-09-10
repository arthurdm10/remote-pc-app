import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/pages/directory_page.dart';
import 'package:remote_pc/pages/processes_page.dart';
import 'package:remote_pc/providers/websocket_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final pcKey = "fc58161e6b0da8e0cae8248f40141165";

  WebSocketProvider ws;

  @override
  void initState() {
    ws = WebSocketProvider("10.0.3.2", 9002, pcKey);
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
            DirectoryPage("/home"),
            ProcessesPage(),
          ],
        ),
      ),
    );
  }
}
