import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:pathplanner/widgets/window_button/window_button.dart';

class HomePage extends StatefulWidget {
  HomePage() : super();

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: kToolbarHeight,
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
            Container(
              height: 160,
              padding: EdgeInsets.all(8),
              child: Align(
                child: Text(
                  'v' + _version,
                  style: TextStyle(fontSize: 15),
                ),
                alignment: FractionalOffset.topLeft,
              ),
            ),
            Divider(),
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
                child: Text('hi'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
