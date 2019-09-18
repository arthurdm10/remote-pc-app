import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qrcode_reader/qrcode_reader.dart';
import 'package:remote_pc/providers/websocket_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/new_connection_dialog.dart';
import 'main_page.dart';

class ConnectPage extends StatelessWidget {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Connect"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.desktop_windows),
            onPressed: () {
              _showConnectionDialog(context);
            },
          )
        ],
      ),
      body: FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.connectionState == ConnectionState.done) {
            final SharedPreferences pref = snapshot.data;

            //its a list of json objects
            final savedPcs = pref.getStringList("pcs");
            int pcIndex = -1;

            if (savedPcs != null) {
              return ListView(
                children: savedPcs.map((String pc) {
                  final jsonData = jsonDecode(pc);
                  ++pcIndex;

                  return Dismissible(
                    key: UniqueKey(),
                    onDismissed: (_) {
                      savedPcs.removeAt(pcIndex);
                      pref.setStringList("pcs", savedPcs);
                      return true;
                    },
                    direction: DismissDirection.endToStart,
                    child: ListTile(
                      onTap: () {
                        _showConnectionDialog(context, jsonData);
                      },
                      title: Text(jsonData["key"]),
                      subtitle: Text('Server ${jsonData["remote_server"]}'),
                    ),
                  );
                }).toList(),
              );
            }
            return Container();
          }
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          //here we use a builder so we can access the scaffold and show a snackbar
          return FloatingActionButton(
            onPressed: () async {
              final codeData = await QRCodeReader()
                  .setAutoFocusIntervalInMs(200) // default 5000
                  .setForceAutoFocus(true) // default false
                  .setTorchEnabled(true) // default false
                  .setHandlePermissions(true) // default true
                  .setExecuteAfterPermissionGranted(true) // default true
                  .scan();

              if (codeData == null || codeData.isEmpty) {
                return;
              }
              _showConnectionDialog(jsonDecode(codeData));
            },
            child: Icon(Icons.photo_camera),
          );
        },
      ),
    );
  }

  _showConnectionDialog(BuildContext context, [Map qrCodeData]) async {
    final Map connectionData = await showDialog(
      context: context,
      builder: (_) => NewConnectionDialog(qrCodeData: qrCodeData),
    );

    if (connectionData != null) {
      final ws = WebSocketProvider(connectionData);

      final connected = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          VoidCallback connect;
          connect = () async {
            if (ws.connectionStatus == WsConnectionStatus.connected) {
              ws.removeListener(connect);
              //close loading dialog
              if (connectionData["save"]) {
                final pref = await SharedPreferences.getInstance();
                final pcs = pref.getStringList("pcs") ?? List<String>();

                pcs.add(jsonEncode({
                  "remote_server": connectionData["remote_server"],
                  "key": connectionData["key"]
                }));

                pref.setStringList("pcs", pcs);
              }

              Navigator.of(context).pop(true);

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    builder: (_) => ws.getCmdResponse("initial_dir"),
                    child: MainPage(ws),
                  ),
                ),
              );
            } else if (ws.connectionStatus == WsConnectionStatus.error) {
              Navigator.of(context).pop(false);
            }
          };

          ws.addListener(connect);

          return Container(
            width: 300,
            height: 350,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );

      if (!connected) {
        _scaffoldKey.currentState.showSnackBar(
          SnackBar(
            content: Text("Failed to connect to PC"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
