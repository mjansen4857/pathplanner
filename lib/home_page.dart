import 'dart:io';
import 'dart:math';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:pathplanner/robot_path.dart';
import 'package:pathplanner/widgets/path_editor/path_editor.dart';
import 'package:pathplanner/widgets/path_tile.dart';
import 'package:pathplanner/widgets/settings_tile.dart';
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
  List<RobotPath> _paths = [];
  RobotPath _currentPath;
  double _robotWidth = 0.75;
  double _robotLength = 1.0;
  bool _holonomicMode = false;

  @override
  void initState() {
    super.initState();
    List<RobotPath> paths = [];
    for (int i = 0; i < 3; i++) {
      paths.add(RobotPath(
        [
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
        ],
        name: 'Path $i',
      ));
    }
    SharedPreferences.getInstance().then((val) {
      setState(() {
        _prefs = val;
        _paths = paths;
        _currentPath = _paths[0];
        String projectDir = _prefs.getString('currentProjectDir');
        if (projectDir != null) {
          _currentProject = Directory(projectDir);
        }
        _robotWidth = _prefs.getDouble('robotWidth') ?? 0.75;
        _robotLength = _prefs.getDouble('robotLength') ?? 1.0;
        _holonomicMode = _prefs.getBool('holonomicMode') ?? false;
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
                    final RobotPath path = _paths.removeAt(oldIndex);
                    _paths.insert(newIndex, path);
                  });
                },
                children: [
                  for (int i = 0; i < _paths.length; i++)
                    PathTile(
                      _paths[i],
                      key: Key('$i'),
                      isSelected: _paths[i] == _currentPath,
                      tapCallback: () {
                        setState(() {
                          _currentPath = _paths[i];
                        });
                      },
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
                        onTap: () {
                          setState(() {
                            _paths.add(RobotPath([
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
                            ]));
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: SettingsTile(
                          onSettingsChanged: () {
                            setState(() {
                              _robotWidth =
                                  _prefs.getDouble('robotWidth') ?? 0.75;
                              _robotLength =
                                  _prefs.getDouble('robotLength') ?? 1.0;
                              _holonomicMode =
                                  _prefs.getBool('holonomicMode') ?? false;
                            });
                          },
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
              _currentPath, _robotWidth, _robotLength, _holonomicMode),
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
