import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/window_button/window_button.dart';

class HomePage extends StatefulWidget {
  HomePage() : super();

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _toolbarHeight = 56;
  String _version = '2022.0.0';
  var _paths = [];

  @override
  void initState() {
    super.initState();
    var paths = [];
    for (int i = 0; i < 10; i++) {
      paths.add('Path ' + (i + 1).toString());
    }
    setState(() {
      _paths = paths;
      if (Platform.isMacOS) {
        _toolbarHeight = 56;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _toolbarHeight,
        title: SizedBox(
          height: _toolbarHeight,
          child: Row(
            children: [
              Expanded(
                child: MoveWindow(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PathPlanner',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  MinimizeWindowBtn(),
                  MaximizeWindowBtn(),
                  CloseWindowBtn(),
                ],
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              child: Stack(
                children: [
                  Container(
                    child: Align(
                        alignment: FractionalOffset.bottomRight,
                        child: Text('v' + _version)),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(),
                          flex: 2,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'No Project',
                            style: TextStyle(fontSize: 20, color: Colors.red),
                          ),
                        ),
                        ElevatedButton(
                            onPressed: () {}, child: Text('Open Project')),
                        Expanded(
                          child: Container(),
                          flex: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView(
                padding: EdgeInsets.zero,
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final String path = _paths.removeAt(oldIndex);
                    _paths.insert(newIndex, path);
                  });
                },
                children: [
                  for (int i = 0; i < _paths.length; i++)
                    ListTile(
                      key: Key('$i'),
                      title: Text(_paths[i]),
                      onTap: () {},
                    ),
                ],
              ),
            ),
            Container(
              child: Align(
                alignment: FractionalOffset.bottomCenter,
                child: Container(
                  child: Column(
                    children: [
                      Divider(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: Icon(Icons.add),
                          title: Text('Add Path'),
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              child: Center(
                child: ElevatedButton(
                  child: Text(
                    'Open Robot Project',
                    style: TextStyle(fontSize: 16),
                  ),
                  onPressed: () async {
                    var typeGroup = XTypeGroup();
                    var projectFolder = getDirectoryPath(
                        confirmButtonText: 'Open Project',
                        initialDirectory: Directory.current.path);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
