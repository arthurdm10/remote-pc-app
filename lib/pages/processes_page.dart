import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remote_pc/providers/websocket_provider.dart';
import 'package:remote_pc/utils.dart';

class ProcessesPage extends StatefulWidget {
  ProcessesPage({Key key}) : super(key: key);

  _ProcessesPageState createState() => _ProcessesPageState();
}

enum SortProcsBy { NAME, CPU, RAM }

class _ProcessesPageState extends State<ProcessesPage>
    with AutomaticKeepAliveClientMixin {
  WebSocketProvider _ws;
  SortProcsBy _sortBy = SortProcsBy.NAME;

  static const _sortKey = {
    SortProcsBy.NAME: "name",
    SortProcsBy.CPU: "cpu_percent",
    SortProcsBy.RAM: "memory_percent",
  };

  @override
  void initState() {
    _ws = Provider.of<WebSocketProvider>(context, listen: false);
    _ws.listProcesses();
    // Timer.periodic(Duration(seconds: 3), (t) => _ws.listProcesses());
    super.initState();
  }

  @override
  bool get wantKeepAlive => true;

  _setSortBy(SortProcsBy sortBy) {
    setState(() {
      _sortBy = sortBy;
    });
  }

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
              procs.sort((p1, p2) {
                final sortKey = _sortKey[_sortBy];
                if (_sortBy == SortProcsBy.NAME) {
                  return p1[sortKey]
                      .toLowerCase()
                      .compareTo(p2[sortKey].toLowerCase());
                }

                return p2[sortKey].compareTo(p1[sortKey]);
              });
              int cpuCount = 1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "CPU",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    GridView.count(
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      crossAxisSpacing: 20,
                      childAspectRatio: 3.5,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      crossAxisSpacing: 20,
                      childAspectRatio: 3.5,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    SizedBox(height: 12),
                    Container(
                      color: Color(0xff2196f3),
                      padding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                      margin: const EdgeInsets.only(bottom: 5),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _setSortBy(SortProcsBy.NAME);
                                },
                                child: Text("NAME"),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: GestureDetector(
                                onTap: () {
                                  _setSortBy(SortProcsBy.CPU);
                                },
                                child: Text("CPU"),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.loose,
                              child: GestureDetector(
                                onTap: () {
                                  _setSortBy(SortProcsBy.RAM);
                                },
                                child: Text("RAM"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        primary: true,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        itemExtent: 20,
                        children: procs.map((proc) {
                          return Dismissible(
                            key: UniqueKey(),
                            onDismissed: (_) {},
                            confirmDismiss: (_) {
                              return Future.delayed(
                                  Duration(seconds: 2), () => true);
                            },
                            dismissThresholds: {DismissDirection.endToStart: 0.2},
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(proc["name"])),
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Text(
                                    '${proc["cpu_percent"].toStringAsFixed(2)}%',
                                  ),
                                ),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    '${proc["memory_percent"].toStringAsFixed(2)}%',
                                  ),
                                ),
                              ],
                            ),
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
