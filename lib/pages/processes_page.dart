import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/providers/websocket_provider.dart';
import 'package:remote_pc/utils.dart';

class ProcessesPage extends StatefulWidget {
  ProcessesPage({Key key}) : super(key: key);

  _ProcessesPageState createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage>
    with AutomaticKeepAliveClientMixin {
  WebSocketProvider _ws;

  @override
  void initState() {
    _ws = Provider.of<WebSocketProvider>(context, listen: false);
    _ws.listProcesses();
    // Timer.periodic(Duration(seconds: 3), (t) => _ws.listProcesses());
    super.initState();
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Processes'),
      ),
      body: ChangeNotifierProvider(
        builder: (_) => _ws.getCmdResponse("ls_ps"),
        child: Builder(builder: (context) {
          return Consumer<CmdResponse>(
            builder: (context, cmdResponse, _) {
              if (cmdResponse.status == CmdResponseStatus.LOADING) {
                return Center(child: CircularProgressIndicator());
              }
              final data = cmdResponse.data["response"];
              final memData = data["memory"];
              final List procs = data["processes"];
              procs.sort(
                  (p1, p2) => p2["memory_percent"].compareTo(p1["memory_percent"]));
              int cpuCount = 1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "CPU",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      crossAxisSpacing: 20,
                      childAspectRatio: 3.5,
                      children: data["cpu"]["percent"].map<Widget>((cpuPercent) {
                        return Text(
                          'CPU ${cpuCount++}: $cpuPercent%',
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "RAM",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      crossAxisSpacing: 20,
                      childAspectRatio: 3.5,
                      children: [
                        Text(
                          'Total: ${fileSizeFormated(memData["total"])}',
                        ),
                        Text(
                          'Used: ${fileSizeFormated(memData["used"])} (${memData["percent"]}%)',
                        ),
                        Text(
                          'Free: ${fileSizeFormated(memData["free"])}',
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        primary: true,
                        children: procs.map((proc) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(proc["name"])),
                              Flexible(
                                fit: FlexFit.tight,
                                child: Text(
                                  proc["cpu_percent"].toStringAsFixed(2),
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  proc["memory_percent"].toStringAsFixed(2),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
