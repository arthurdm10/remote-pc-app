import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/pages/directory_page.dart';
import 'package:remote_pc/providers/websocket_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final pcKey = "fc58161e6b0da8e0cae8248f40141165";

  @override
  Widget build(BuildContext context) {
    final ws = WebSocketProvider("10.0.3.2", 9002, pcKey);
    return MaterialApp(
      title: 'Material App',
      home: MultiProvider(
        providers: [
          Provider.value(value: ws),
          StreamProvider<String>.value(value: ws.conn.stream.cast<String>())
        ],
        child: DirectoryPage("/home/frost"),
      ),
    );
  }
}
