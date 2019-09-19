import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

class NewConnectionDialog extends StatefulWidget {
  Map qrCodeData;

  NewConnectionDialog({Map qrCodeData}) {
    this.qrCodeData = qrCodeData;
  }

  @override
  _NewConnectionDialogState createState() => _NewConnectionDialogState();
}

class _NewConnectionDialogState extends State<NewConnectionDialog> {
  String _remoteServer, _pcKey;
  List<FocusNode> _inputsFocus = [FocusNode(), FocusNode(), FocusNode()];
  bool _saveConnection = false;

  final _formGlobalKey = GlobalKey<FormState>();

  final _serverInputController = TextEditingController(),
      _keyInputController = TextEditingController(),
      _usernameInputController = TextEditingController(),
      _passwordInputController = TextEditingController();

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
              Row(
                children: <Widget>[
                  Text("Save connection"),
                  Checkbox(
                    value: _saveConnection,
                    onChanged: (save) {
                      setState(() {
                        _saveConnection = save;
                      });
                    },
                  ),
                ],
              )
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
                "username":
                    sha256.convert(utf8.encode(_usernameInputController.text)),
                "password":
                    sha256.convert(utf8.encode(_passwordInputController.text)),
                "save": _saveConnection,
              });
            }
          },
        )
      ],
    );
  }
}
