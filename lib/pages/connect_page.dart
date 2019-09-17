import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qrcode_reader/qrcode_reader.dart';
import 'package:remote_pc/providers/websocket_provider.dart';

import 'main_page.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Connect"),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            //here we use a builder so we can access the scaffold and show a snackbar
            return FloatingActionButton(
              onPressed: () async {
                // final codeData = await QRCodeReader()
                //     .setAutoFocusIntervalInMs(200) // default 5000
                //     .setForceAutoFocus(true) // default false
                //     .setTorchEnabled(true) // default false
                //     .setHandlePermissions(true) // default true
                //     .setExecuteAfterPermissionGranted(true) // default true
                //     .scan();

                // if (codeData == null || codeData.isEmpty) {
                //   return;
                // }

                final Map connectionData = await showDialog(
                  context: context,
                  builder: (_) => NewConnectionDialog(qrCodeData: jsonDecode("{}")),
                );

                if (connectionData != null) {
                  final ws = WebSocketProvider(connectionData);

                  final connected = await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      VoidCallback connect;
                      connect = () {
                        if (ws.connectionStatus == WsConnectionStatus.connected) {
                          //close loading dialog
                          ws.removeListener(connect);
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
                    Scaffold.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to connect to PC"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: Icon(Icons.photo_camera),
            );
          },
        ),
      ),
    );
  }
}

class NewConnectionDialog extends StatefulWidget {
  Map qrCodeData;

  NewConnectionDialog({Map qrCodeData}) {
    // this.qrCodeData = qrCodeData;
    this.qrCodeData = {"remote_server": "10.0.3.2:9002", "key": "key123"};
  }

  @override
  _NewConnectionDialogState createState() => _NewConnectionDialogState();
}

class _NewConnectionDialogState extends State<NewConnectionDialog> {
  String _remoteServer, _pcKey;
  List<FocusNode> _inputsFocus = [FocusNode(), FocusNode(), FocusNode()];

  final _formGlobalKey = GlobalKey<FormState>();

  final _serverInputController = TextEditingController(),
      _keyInputController = TextEditingController(),
      _usernameInputController = TextEditingController(text: "user"),
      _passwordInputController = TextEditingController(text: "passwd");

  @override
  void initState() {
    super.initState();

    if (widget.qrCodeData != null) {
      _remoteServer = widget.qrCodeData["remote_server"];
      _pcKey = widget.qrCodeData["key"];
      _serverInputController.text = _remoteServer;
      _keyInputController.text = _pcKey;
    }
  }

  @override
  void dispose() {
    for (final focus in _inputsFocus) {
      focus.dispose();
    }

    super.dispose();
  }

  String _formFieldValidator(String text, {@required String fieldName}) {
    return text.trim().isEmpty ? 'Invalid $fieldName' : null;
  }

  _changeFocus(int i) {
    FocusScope.of(context).requestFocus(_inputsFocus[i]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("New connection"),
      content: SingleChildScrollView(
        child: Form(
          key: _formGlobalKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _changeFocus(0),
                validator: (text) =>
                    _formFieldValidator(text, fieldName: "server address"),
                controller: _serverInputController,
                decoration: InputDecoration(
                  labelText: "Server address",
                  contentPadding: const EdgeInsets.all(2),
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                focusNode: _inputsFocus[0],
                onEditingComplete: () => _changeFocus(1),
                textInputAction: TextInputAction.next,
                validator: (text) => _formFieldValidator(text, fieldName: "PC key"),
                controller: _keyInputController,
                decoration: InputDecoration(
                  labelText: "PC Key",
                  contentPadding: const EdgeInsets.all(2),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                focusNode: _inputsFocus[1],
                onEditingComplete: () => _changeFocus(2),
                textInputAction: TextInputAction.next,
                validator: (text) =>
                    _formFieldValidator(text, fieldName: "username"),
                controller: _usernameInputController,
                decoration: InputDecoration(
                  labelText: "Username",
                  contentPadding: const EdgeInsets.all(2),
                ),
              ),
              TextFormField(
                focusNode: _inputsFocus[2],
                textInputAction: TextInputAction.done,
                validator: (text) =>
                    _formFieldValidator(text, fieldName: "password"),
                controller: _passwordInputController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  contentPadding: const EdgeInsets.all(2),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FlatButton(
          child: Text("Connect"),
          onPressed: () {
            if (_formGlobalKey.currentState.validate()) {
              Navigator.of(context).pop({
                "remote_server": _serverInputController.text,
                "key": _keyInputController.text,
                "username": _usernameInputController.text,
                "password": _passwordInputController.text
              });
            }
          },
        )
      ],
    );
  }
}
