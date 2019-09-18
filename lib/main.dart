import 'package:flutter/material.dart';
import 'package:remote_pc/pages/connect_page.dart';

//nukedoom

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Remote PC',
      home: ConnectPage(),
    );
  }
}
