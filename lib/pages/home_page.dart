import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pathplanner/pages/welcome_page.dart';
import 'package:pathplanner/robot_path/robot_path.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/custom_appbar.dart';
import 'package:pathplanner/widgets/deploy_fab.dart';
import 'package:pathplanner/widgets/drawer_tiles/path_tile.dart';
import 'package:pathplanner/widgets/drawer_tiles/settings_tile.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/keyboard_shortcuts.dart';
import 'package:pathplanner/widgets/path_editor/path_editor.dart';
import 'package:pathplanner/widgets/update_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final FieldImage defaultFieldImage;
  final String appVersion;
  final bool appStoreBuild;

  HomePage(
    this.defaultFieldImage, {
    this.appVersion = '0.0.0',
    this.appStoreBuild = false,
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  Directory? _projectDir;
  late SharedPreferences _prefs;
  List<RobotPath> _paths = [];
  RobotPath? _currentPath;
  Size _robotSize = Size(0.75, 1.0);
  bool _holonomicMode = false;
  bool _generateJSON = false;
  bool _generateCSV = false;
  SecureBookmarks? _bookmarks = Platform.isMacOS ? SecureBookmarks() : null;
  List<FieldImage> _fieldImages = FieldImage.offialFields();
  FieldImage? _fieldImage;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();

    _animController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 250));
    _scaleAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.ease);

    _loadFieldImages().then((_) {
      SharedPreferences.getInstance().then((prefs) async {
        _prefs = prefs;

        String? projectDir = prefs.getString('currentProjectDir');
        if (projectDir != null && Platform.isMacOS) {
          if (_prefs.getString('macOSBookmark') != null) {
            await _bookmarks!
                .resolveBookmark(_prefs.getString('macOSBookmark')!);

            await _bookmarks!
                .startAccessingSecurityScopedResource(File(projectDir));
          } else {
            projectDir = null;
          }
        }

        if (projectDir == null) {
          projectDir = await Navigator.push(
            _key.currentContext!,
            PageRouteBuilder(
              pageBuilder: (context, anim1, anim2) => WelcomePage(
                widget.defaultFieldImage,
                appVersion: widget.appVersion,
              ),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );

          _prefs.setString('currentProjectDir', projectDir!);
          _prefs.remove('pathOrder');

          if (Platform.isMacOS) {
            // Bookmark project on macos so it can be accessed again later
            String bookmark = await _bookmarks!.bookmark(File(projectDir));
            _prefs.setString('macOSBookmark', bookmark);
          }
        }

        setState(() {
          _projectDir = Directory(projectDir!);

          _paths = _loadPaths(_projectDir!);
          _currentPath = _paths[0];
          _robotSize = Size(_prefs.getDouble('robotWidth') ?? 0.75,
              _prefs.getDouble('robotLength') ?? 1.0);
          _holonomicMode = _prefs.getBool('holonomicMode') ?? false;
          _generateJSON = _prefs.getBool('generateJSON') ?? false;
          _generateCSV = _prefs.getBool('generateCSV') ?? false;

          String? selectedFieldName = _prefs.getString('fieldImage');
          if (selectedFieldName != null) {
            for (FieldImage image in _fieldImages) {
              if (image.name == selectedFieldName) {
                _fieldImage = image;
                break;
              }
            }
          }

          _animController.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (Platform.isMacOS && _projectDir != null) {
      _bookmarks!.stopAccessingSecurityScopedResource(File(_projectDir!.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      appBar: CustomAppBar(
        titleText: _currentPath == null ? 'PathPlanner' : _currentPath!.name,
      ),
      drawer: _projectDir == null ? null : _buildDrawer(context),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildBody(),
      ),
      floatingActionButton: Visibility(
        visible:
            _projectDir != null && (!widget.appStoreBuild && !Platform.isMacOS),
        child: DeployFAB(_projectDir),
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
                      child: Text('v' + widget.appVersion)),
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
                          (_projectDir != null)
                              ? basename(_projectDir!.path)
                              : 'No Project',
                          style: TextStyle(
                              fontSize: 20,
                              color: (_projectDir != null)
                                  ? Colors.white
                                  : Colors.red),
                        ),
                      ),
                      ElevatedButton(
                          onPressed: () {
                            _openProjectDialog(context);
                          },
                          child: Text('Switch Project')),
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
                      Directory pathsDir = _getPathsDir(_projectDir!);

                      File pathFile =
                          File(join(pathsDir.path, _paths[i].name + '.path'));
                      File newPathFile =
                          File(join(pathsDir.path, name + '.path'));
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
                        pathFile.rename(join(pathsDir.path, name + '.path'));
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

                      Directory pathsDir = _getPathsDir(_projectDir!);

                      File pathFile =
                          File(join(pathsDir.path, _paths[i].name + '.path'));

                      if (pathFile.existsSync()) {
                        // The fitted text field container does not rebuild
                        // itself correctly so this is a way to hide it and
                        // avoid confusion. (Hides drawer)
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
                        _savePath(_currentPath!);
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
                          _paths.add(RobotPath.defaultPath(name: pathName));
                          _currentPath = _paths.last;
                          _savePath(_currentPath!);
                          UndoRedo.clearHistory();
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: SettingsTile(
                        _fieldImages,
                        selectedField: _fieldImage,
                        onFieldSelected: (FieldImage image) {
                          setState(() {
                            _fieldImage = image;
                            if (!_fieldImages.contains(image)) {
                              _fieldImages.add(image);
                            }
                            _prefs.setString('fieldImage', image.name);
                          });
                        },
                        onSettingsChanged: () {
                          setState(() {
                            _robotSize = Size(
                                _prefs.getDouble('robotWidth') ?? 0.75,
                                _prefs.getDouble('robotLength') ?? 1.0);
                            _holonomicMode =
                                _prefs.getBool('holonomicMode') ?? false;
                            _generateJSON =
                                _prefs.getBool('generateJSON') ?? false;
                            _generateCSV =
                                _prefs.getBool('generateCSV') ?? false;
                          });
                        },
                        onGenerationEnabled: () {
                          for (RobotPath path in _paths) {
                            _savePath(path);
                          }
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

  Widget _buildBody() {
    if (_projectDir != null) {
      return Stack(
        children: [
          Center(
            child: Container(
              child: PathEditor(
                _fieldImage ?? widget.defaultFieldImage,
                _currentPath!,
                _robotSize,
                _holonomicMode,
                showGeneratorSettings: _generateJSON || _generateCSV,
                savePath: (path) => _savePath(path),
                prefs: _prefs,
              ),
            ),
          ),
          if (!widget.appStoreBuild) UpdateCard(widget.appVersion),
        ],
      );
    } else {
      return Container();
    }
  }

  List<RobotPath> _loadPaths(Directory projectDir) {
    List<RobotPath> paths = [];

    Directory pathsDir = _getPathsDir(projectDir);
    if (!pathsDir.existsSync()) {
      pathsDir.createSync(recursive: true);
    }

    List<FileSystemEntity> pathFiles = pathsDir.listSync();
    for (FileSystemEntity e in pathFiles) {
      if (e.path.endsWith('.path')) {
        String json = File(e.path).readAsStringSync();
        try {
          RobotPath p = RobotPath.fromJson(jsonDecode(json));
          p.name = basenameWithoutExtension(e.path);
          paths.add(p);
        } catch (e) {
          // Path is not in correct format. Don't add it
        }
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
      orderedPaths.add(RobotPath.defaultPath());
    }

    return orderedPaths;
  }

  Directory _getPathsDir(Directory projectDir) {
    File buildFile = File(join(projectDir.path, 'build.gradle'));

    if (buildFile.existsSync()) {
      // Java or C++ project
      return Directory(
          join(projectDir.path, 'src', 'main', 'deploy', 'pathplanner'));
    } else {
      // Other language
      return Directory(join(projectDir.path, 'deploy', 'pathplanner'));
    }
  }

  void _savePath(RobotPath path) {
    if (_projectDir != null) {
      path.savePath(_getPathsDir(_projectDir!), _generateJSON, _generateCSV);
    }
  }

  void _openProjectDialog(BuildContext context) async {
    String? projectFolder = await getDirectoryPath(
        confirmButtonText: 'Open Project',
        initialDirectory: Directory.current.path);
    if (projectFolder != null) {
      Directory pathsDir = _getPathsDir(Directory(projectFolder));

      pathsDir.createSync(recursive: true);
      _prefs.setString('currentProjectDir', projectFolder);
      _prefs.remove('pathOrder');

      if (Platform.isMacOS) {
        // Bookmark project on macos so it can be accessed again later
        String bookmark = await _bookmarks!.bookmark(File(projectFolder));
        _prefs.setString('macOSBookmark', bookmark);
      }

      setState(() {
        _projectDir = Directory(projectFolder);
        _loadPaths(_projectDir!);
      });
    }
  }

  Future<void> _loadFieldImages() async {
    Directory appDir = await getApplicationSupportDirectory();
    Directory imagesDir = Directory(join(appDir.path, 'custom_fields'));

    imagesDir.createSync(recursive: true);

    List<FileSystemEntity> fileEntities = imagesDir.listSync();
    for (FileSystemEntity e in fileEntities) {
      _fieldImages.add(FieldImage.custom(File(e.path)));
    }
  }
}
