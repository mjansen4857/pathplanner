import 'dart:io';
import 'dart:math';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fitted_text_field_container/fitted_text_field_container.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:pathplanner/robot_path.dart';
import 'package:pathplanner/widgets/path_editor/path_editor.dart';
import 'package:pathplanner/widgets/window_button/window_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  HomePage() : super();

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _toolbarHeight = 56;
  String _version = '2022.0.0';
  Directory _currentProject;
  SharedPreferences _prefs;
  var _paths = [];

  @override
  void initState() {
    super.initState();
    var paths = [];
    for (int i = 0; i < 10; i++) {
      paths.add('Path ' + (i + 1).toString());
    }
    SharedPreferences.getInstance().then((val) {
      _prefs = val;
      setState(() {
        _paths = paths;
        String projectDir = _prefs.getString('currentProjectDir');
        if (projectDir != null) {
          _currentProject = Directory(projectDir);
        }
      });
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
                            (_currentProject != null)
                                ? basename(_currentProject.path)
                                : 'No Project',
                            style: TextStyle(
                                fontSize: 20,
                                color: (_currentProject != null)
                                    ? Colors.white
                                    : Colors.red),
                          ),
                        ),
                        ElevatedButton(
                            onPressed: openProjectDialog,
                            child: Text('Open Project')),
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
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: FittedTextFieldContainer(
                          child: TextField(
                            cursorColor: Colors.white,
                            onSubmitted: (String text) {
                              FocusScopeNode currentScope =
                                  FocusScope.of(context);
                              if (!currentScope.hasPrimaryFocus &&
                                  currentScope.hasFocus) {
                                FocusManager.instance.primaryFocus.unfocus();
                              }
                              setState(() {
                                _paths[i] = text;
                              });
                            },
                            controller: TextEditingController(text: _paths[i]),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.transparent,
                                ),
                              ),
                              // errorBorder: InputBorder.none,
                              // disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.all(8),
                            ),
                          ),
                        ),
                      ),
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
                      ListTile(
                        leading: Icon(Icons.add),
                        title: Text('Add Path'),
                        onTap: () {},
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: Icon(Icons.settings),
                          title: Text('Settings'),
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
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (_currentProject != null) {
      return Center(
        child: Container(
          // color: Colors.grey,
          child: PathEditor(
            RobotPath([
              Waypoint(
                anchorPoint: Point(1.0, 3.0),
                nextControl: Point(2.0, 3.0),
              ),
              Waypoint(
                prevControl: Point(3.0, 4.0),
                anchorPoint: Point(3.0, 5.0),
                isReversal: true,
              ),
              Waypoint(
                prevControl: Point(4.0, 3.0),
                anchorPoint: Point(5.0, 3.0),
              ),
            ], 'test'),
          ),
        ),
      );
    } else {
      return Center(
        child: ElevatedButton(
          child: Text(
            'Open Robot Project',
            style: TextStyle(fontSize: 16),
          ),
          onPressed: openProjectDialog,
        ),
      );
    }
  }

  void openProjectDialog() async {
    var projectFolder = await getDirectoryPath(
        confirmButtonText: 'Open Project',
        initialDirectory: Directory.current.path);
    _prefs.setString('currentProjectDir', projectFolder);
    setState(() {
      _currentProject = Directory(projectFolder);
    });
  }
}
