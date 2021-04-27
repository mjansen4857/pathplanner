import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/robot_path/waypoint.dart';
import 'package:pathplanner/services/github.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/drawer_tiles/path_tile.dart';
import 'package:pathplanner/widgets/drawer_tiles/settings_tile.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/path_editor/path_editor.dart';
import 'package:pathplanner/widgets/window_button/window_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  HomePage() : super();

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  double _toolbarHeight = 56;
  String _version = '2022.0.0';
  Directory? _currentProject;
  Directory? _pathsDir;
  late SharedPreferences _prefs;
  List<RobotPath> _paths = [];
  RobotPath? _currentPath;
  double _robotWidth = 0.75;
  double _robotLength = 1.0;
  bool _holonomicMode = false;
  bool _updateAvailable = false;
  late AnimationController _updateController;
  late AnimationController _welcomeController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;
  String _releaseURL =
      'https://github.com/mjansen4857/pathplanner/releases/latest';

  @override
  void initState() {
    super.initState();
    _updateController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 400));
    _welcomeController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 400));
    _offsetAnimation = Tween<Offset>(begin: Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _updateController,
      curve: Curves.ease,
    ));
    _scaleAnimation =
        CurvedAnimation(parent: _welcomeController, curve: Curves.ease);
    SharedPreferences.getInstance().then((val) {
      setState(() {
        _prefs = val;
        _welcomeController.forward();

        String? projectDir = _prefs.getString('currentProjectDir');
        _loadPaths(projectDir);
        _robotWidth = _prefs.getDouble('robotWidth') ?? 0.75;
        _robotLength = _prefs.getDouble('robotLength') ?? 1.0;
        _holonomicMode = _prefs.getBool('holonomicMode') ?? false;
      });
    });

    GitHubAPI.isUpdateAvailable(_version).then((value) {
      setState(() {
        _updateAvailable = value;
        _updateController.forward();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _updateController.dispose();
    _welcomeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar() as PreferredSizeWidget?,
      drawer: _currentProject == null ? null : _buildDrawer(context),
      body: Stack(
        children: [
          _buildBody(context),
          _buildUpdateNotification(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      toolbarHeight: _toolbarHeight,
      actions: [
        MinimizeWindowBtn(),
        MaximizeWindowBtn(),
        CloseWindowBtn(),
      ],
      title: SizedBox(
        height: _toolbarHeight,
        child: Row(
          children: [
            Expanded(
              child: MoveWindow(
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currentPath == null
                        ? 'PathPlanner'
                        : '${_currentPath!.name}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
                              ? basename(_currentProject!.path)
                              : 'No Project',
                          style: TextStyle(
                              fontSize: 20,
                              color: (_currentProject != null)
                                  ? Colors.white
                                  : Colors.red),
                        ),
                      ),
                      ElevatedButton(
                          onPressed: () {
                            _openProjectDialog(context);
                          },
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

                  List<String> pathOrder = [];
                  for (RobotPath path in _paths) {
                    pathOrder.add(path.name);
                  }
                  _prefs.setStringList('pathOrder', pathOrder);
                });
              },
              children: [
                for (int i = 0; i < _paths.length; i++)
                  PathTile(
                    _paths[i],
                    key: Key('$i'),
                    isSelected: _paths[i] == _currentPath,
                    onRename: (name) {
                      File pathFile =
                          File(_pathsDir!.path + _paths[i].name + '.path');
                      File newPathFile = File(_pathsDir!.path + name + '.path');
                      if (newPathFile.existsSync() &&
                          newPathFile.path != pathFile.path) {
                        Navigator.of(context).pop();
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return KeyBoardShortcuts(
                                keysToPress: {LogicalKeyboardKey.enter},
                                onKeysPressed: Navigator.of(context).pop,
                                child: AlertDialog(
                                  title: Text('Unable to Rename'),
                                  content: Text(
                                      'The file "${basename(newPathFile.path)}" already exists'),
                                  actions: [
                                    TextButton(
                                      onPressed: Navigator.of(context).pop,
                                      child: Text(
                                        'OK',
                                        style: TextStyle(
                                            color: Colors.indigoAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            });
                        return false;
                      } else {
                        pathFile.rename(_pathsDir!.path + name + '.path');
                        setState(() {
                          //flutter weird
                          _currentPath!.name = _currentPath!.name;
                        });
                        return true;
                      }
                    },
                    onTap: () {
                      setState(() {
                        _currentPath = _paths[i];
                        UndoRedo.clearHistory();
                      });
                    },
                    onDelete: () {
                      UndoRedo.clearHistory();

                      File pathFile =
                          File(_pathsDir!.path + _paths[i].name + '.path');

                      if (pathFile.existsSync()) {
                        // The fitted text field container does not rebuild
                        // itself correctly so this is a way to hide it and
                        // avoid confusion
                        Navigator.of(context).pop();

                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              void confirm() {
                                Navigator.of(context).pop();
                                pathFile.delete();
                                setState(() {
                                  if (_currentPath == _paths.removeAt(i)) {
                                    _currentPath = _paths.first;
                                  }
                                });
                              }

                              return KeyBoardShortcuts(
                                keysToPress: {LogicalKeyboardKey.enter},
                                onKeysPressed: confirm,
                                child: AlertDialog(
                                  title: Text('Delete Path'),
                                  content: Text(
                                      'Are you sure you want to delete "${_paths[i].name}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                            color: Colors.indigoAccent),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: confirm,
                                      child: Text(
                                        'Confirm',
                                        style: TextStyle(
                                            color: Colors.indigoAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            });
                      } else {
                        setState(() {
                          if (_currentPath == _paths.removeAt(i)) {
                            _currentPath = _paths.first;
                          }
                        });
                      }
                    },
                    onDuplicate: () {
                      UndoRedo.clearHistory();
                      setState(() {
                        List<String> pathNames = [];
                        for (RobotPath path in _paths) {
                          pathNames.add(path.name);
                        }
                        String pathName = _paths[i].name + ' Copy';
                        while (pathNames.contains(pathName)) {
                          pathName = pathName + ' Copy';
                        }
                        _paths.add(RobotPath(
                          RobotPath.cloneWaypointList(_paths[i].waypoints),
                          name: pathName,
                        ));
                        _currentPath = _paths.last;
                        _currentPath!.savePath(_pathsDir!.path);
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
                        List<String> pathNames = [];
                        for (RobotPath path in _paths) {
                          pathNames.add(path.name);
                        }
                        String pathName = 'New Path';
                        while (pathNames.contains(pathName)) {
                          pathName = 'New ' + pathName;
                        }
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
                          ], name: pathName));
                          _currentPath = _paths.last;
                          _currentPath!.savePath(_pathsDir!.path);
                          UndoRedo.clearHistory();
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
    );
  }

  Widget _buildUpdateNotification() {
    return Visibility(
      visible: _updateAvailable,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: FractionalOffset.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              color: Colors.white.withOpacity(0.13),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Update Available!',
                          style: TextStyle(fontSize: 20),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (await canLaunch(_releaseURL)) {
                              launch(_releaseURL);
                            }
                          },
                          child: Text(
                            'Update',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_currentProject != null) {
      return Center(
        child: Container(
          child: PathEditor(_currentPath!, _robotWidth, _robotLength,
              _holonomicMode, _pathsDir!.path),
        ),
      );
    } else {
      return Stack(
        children: [
          Center(child: Image.asset('images/field20.png')),
          Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.15),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 250,
                              height: 250,
                              child: Image(
                                image: AssetImage('images/icon.png'),
                              )),
                          Text(
                            'PathPlanner',
                            style: TextStyle(fontSize: 48),
                          ),
                          SizedBox(height: 96),
                          ElevatedButton(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(
                                'Open WPILib Project',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                                primary: Colors.grey[700]),
                            onPressed: () {
                              _openProjectDialog(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  void _loadPaths(String? projectDir) {
    if (projectDir != null) {
      List<RobotPath> paths = [];
      _currentProject = Directory(projectDir);
      _pathsDir = Directory(projectDir + '/src/main/deploy/pathplanner/');
      List<FileSystemEntity> pathFiles = _pathsDir!.listSync();
      for (FileSystemEntity e in pathFiles) {
        if (e.path.endsWith('.path')) {
          String json = File(e.path).readAsStringSync();
          RobotPath p = RobotPath.fromJson(jsonDecode(json));
          p.name = basenameWithoutExtension(e.path);
          paths.add(p);
        }
      }
      List<String>? pathOrder = _prefs.getStringList('pathOrder');
      List<String> loadedOrder = [];
      for (RobotPath path in paths) {
        loadedOrder.add(path.name);
      }
      List<RobotPath> orderedPaths = [];
      if (pathOrder != null) {
        for (String name in pathOrder) {
          int loadedIndex = loadedOrder.indexOf(name);
          if (loadedIndex != -1) {
            loadedOrder.removeAt(loadedIndex);
            orderedPaths.add(paths.removeAt(loadedIndex));
          }
        }
        for (RobotPath path in paths) {
          orderedPaths.add(path);
        }
      } else {
        orderedPaths = paths;
      }
      if (orderedPaths.length == 0) {
        orderedPaths.add(RobotPath(
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
          name: 'New Path',
        ));
      }
      _paths = orderedPaths;
      _currentPath = _paths[0];
    }
  }

  void _openProjectDialog(BuildContext context) async {
    var projectFolder = await getDirectoryPath(
        confirmButtonText: 'Open Project',
        initialDirectory: Directory.current.path);
    if (projectFolder != null) {
      File buildFile = File(projectFolder + '/build.gradle');
      if (buildFile.existsSync()) {
        Directory pathsDir =
            Directory(projectFolder + '/src/main/deploy/pathplanner');
        pathsDir.create(recursive: true);
        _prefs.setString('currentProjectDir', projectFolder);
        _prefs.remove('pathOrder');
        setState(() {
          _currentProject = Directory(projectFolder);
          _loadPaths(_currentProject!.path);
        });
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return KeyBoardShortcuts(
              keysToPress: {LogicalKeyboardKey.enter},
              onKeysPressed: Navigator.of(context).pop,
              child: AlertDialog(
                title: Text('Invalid Project'),
                content: Text(
                    '$projectFolder is not a valid WPILib gradleRIO project'),
                actions: [
                  TextButton(
                    onPressed: Navigator.of(context).pop,
                    child: Text(
                      'OK',
                      style: TextStyle(color: Colors.indigoAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    }
  }
}
