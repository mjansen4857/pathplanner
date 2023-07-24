import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:path/path.dart';
import 'package:pathplanner/pages/auto_editor_page.dart';
import 'package:pathplanner/pages/path_editor_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/path/pathplanner_auto.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/prefs_keys.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectPage extends StatefulWidget {
  final SharedPreferences prefs;
  final FieldImage fieldImage;
  final Directory projectDirectory;

  const ProjectPage({
    super.key,
    required this.prefs,
    required this.fieldImage,
    required this.projectDirectory,
  });

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final MultiSplitViewController _controller = MultiSplitViewController();
  List<PathPlannerPath> _paths = [];
  List<PathPlannerAuto> _autos = [];
  int _pathGridCount = 2;
  late Directory _pathsDirectory;
  late Directory _autosDirectory;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    double leftWeight =
        widget.prefs.getDouble(PrefsKeys.projectLeftWeight) ?? 0.5;
    _pathGridCount = _getCrossAxisCountForWeight(leftWeight);
    _controller.areas = [
      Area(
        weight: leftWeight,
        minimalWeight: 0.25,
      ),
      Area(
        weight: 1.0 - leftWeight,
        minimalWeight: 0.25,
      ),
    ];

    // Check if WPILib project
    var fs = const LocalFileSystem();
    fs
        .file(join(widget.projectDirectory.path, 'build.gradle'))
        .exists()
        .then((exists) async {
      Directory deployDir;
      if (exists) {
        deployDir = fs.directory(join(widget.projectDirectory.path, 'src',
            'main', 'deploy', 'pathplanner'));
      } else {
        deployDir = fs.directory(
            join(widget.projectDirectory.path, 'deploy', 'pathplanner'));
      }

      // Make sure dirs exist
      _pathsDirectory = fs.directory(join(deployDir.path, 'paths'));
      _pathsDirectory.createSync(recursive: true);
      _autosDirectory = fs.directory(join(deployDir.path, 'autos'));
      _autosDirectory.createSync(recursive: true);

      var paths = await PathPlannerPath.loadAllPathsInDir(_pathsDirectory.path);
      paths.sort((a, b) => a.name.compareTo(b.name));
      var autos = await PathPlannerAuto.loadAllAutosInDir(_autosDirectory.path);
      autos.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _paths = paths;
        _autos = autos;

        if (_paths.isEmpty) {
          _paths.add(PathPlannerPath.defaultPath(
            pathDir: _pathsDirectory.path,
            name: 'Example Path',
          ));
        }

        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: colorScheme.surfaceTint.withOpacity(0.05),
      child: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerPainter: DividerPainters.grooved1(
            color: colorScheme.surfaceVariant,
            highlightedColor: colorScheme.primary,
          ),
        ),
        child: MultiSplitView(
          axis: Axis.horizontal,
          controller: _controller,
          onWeightChange: () {
            setState(() {
              _pathGridCount =
                  _getCrossAxisCountForWeight(_controller.areas[0].weight!);
            });
            widget.prefs.setDouble(PrefsKeys.projectLeftWeight,
                _controller.areas[0].weight ?? 0.5);
          },
          children: [
            _buildPathsGrid(context),
            _buildAutosGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPathsGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Card(
        elevation: 0.0,
        margin: const EdgeInsets.all(0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Paths',
                    style: TextStyle(fontSize: 32),
                  ),
                  Expanded(child: Container()),
                  Tooltip(
                    message: 'Add new path',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton.filledTonal(
                      onPressed: () {
                        List<String> pathNames = [];
                        for (PathPlannerPath path in _paths) {
                          pathNames.add(path.name);
                        }
                        String pathName = 'New Path';
                        while (pathNames.contains(pathName)) {
                          pathName = 'New $pathName';
                        }

                        setState(() {
                          _paths.add(PathPlannerPath.defaultPath(
                            pathDir: _pathsDirectory.path,
                            name: pathName,
                          ));
                        });
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: GridView.count(
                  crossAxisCount: _pathGridCount,
                  childAspectRatio: 1.55,
                  children: [
                    for (int i = 0; i < _paths.length; i++)
                      ProjectItemCard(
                        name: _paths[i].name,
                        fieldImage: widget.fieldImage,
                        paths: [_paths[i]],
                        onDuplicated: () {
                          List<String> pathNames = [];
                          for (PathPlannerPath path in _paths) {
                            pathNames.add(path.name);
                          }
                          String pathName = 'Copy of ${_paths[i].name}';
                          while (pathNames.contains(pathName)) {
                            pathName = 'Copy of $pathName';
                          }

                          setState(() {
                            _paths.add(_paths[i].duplicate(pathName));
                          });
                        },
                        onDeleted: () {
                          _paths[i].deletePath();
                          setState(() {
                            _paths.removeAt(i);
                          });
                        },
                        onRenamed: (value) {
                          _renamePath(i, value, context);
                        },
                        onOpened: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PathEditorPage(
                                prefs: widget.prefs,
                                path: _paths[i],
                                fieldImage: widget.fieldImage,
                                onRenamed: (value) {
                                  _renamePath(i, value, context);
                                },
                              ),
                            ),
                          );

                          // Wait for the user to go back then rebuild so the path preview updates (most of the time...)
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _renamePath(int pathIdx, String newName, BuildContext context) {
    List<String> pathNames = [];
    for (PathPlannerPath path in _paths) {
      pathNames.add(path.name);
    }

    if (pathNames.contains(newName)) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Unable to Rename'),
              content: Text('The file "$newName.path" already exists'),
              actions: [
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('OK'),
                ),
              ],
            );
          });
    } else {
      setState(() {
        String oldName = _paths[pathIdx].name;
        _paths[pathIdx].renamePath(newName);
        for (PathPlannerAuto auto in _autos) {
          auto.updatePathName(oldName, newName);
        }
      });
    }
  }

  int _getCrossAxisCountForWeight(double weight) {
    if (weight < 0.4) {
      return 1;
    } else if (weight < 0.6) {
      return 2;
    } else {
      return 3;
    }
  }

  Widget _buildAutosGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      child: Card(
        elevation: 0.0,
        margin: const EdgeInsets.all(0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Autos',
                    style: TextStyle(fontSize: 32),
                  ),
                  Expanded(child: Container()),
                  Tooltip(
                    message: 'Add new auto',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton.filledTonal(
                      onPressed: () {
                        List<String> autoNames = [];
                        for (PathPlannerAuto auto in _autos) {
                          autoNames.add(auto.name);
                        }
                        String autoName = 'New Auto';
                        while (autoNames.contains(autoName)) {
                          autoName = 'New $autoName';
                        }

                        setState(() {
                          _autos.add(PathPlannerAuto.defaultAuto(
                            autoDir: _autosDirectory.path,
                            name: autoName,
                          ));
                        });
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4 - _pathGridCount,
                  childAspectRatio: 1.55,
                  children: [
                    for (int i = 0; i < _autos.length; i++)
                      ProjectItemCard(
                        name: _autos[i].name,
                        fieldImage: widget.fieldImage,
                        paths: _getPathsFromNames(_autos[i].getAllPathNames()),
                        onDuplicated: () {
                          List<String> autoNames = [];
                          for (PathPlannerAuto auto in _autos) {
                            autoNames.add(auto.name);
                          }
                          String autoName = 'Copy of ${_autos[i].name}';
                          while (autoNames.contains(autoName)) {
                            autoName = 'Copy of $autoName';
                          }

                          setState(() {
                            _autos.add(_autos[i].duplicate(autoName));
                          });
                        },
                        onDeleted: () {
                          _autos[i].delete();
                          setState(() {
                            _autos.removeAt(i);
                          });
                        },
                        onRenamed: (value) {
                          _renameAuto(i, value, context);
                        },
                        onOpened: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AutoEditorPage(
                                prefs: widget.prefs,
                                auto: _autos[i],
                                allPaths: _paths,
                                allPathNames:
                                    _paths.map((e) => e.name).toList(),
                                fieldImage: widget.fieldImage,
                                onRenamed: (value) {
                                  _renameAuto(i, value, context);
                                },
                              ),
                            ),
                          );

                          // Wait for the user to go back then rebuild so the path preview updates (most of the time...)
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PathPlannerPath> _getPathsFromNames(List<String> names) {
    List<PathPlannerPath> paths = [];
    for (String name in names) {
      List<PathPlannerPath> matched =
          _paths.where((path) => path.name == name).toList();
      if (matched.isNotEmpty) {
        paths.add(matched[0]);
      }
    }
    return paths;
  }

  void _renameAuto(int autoIdx, String newName, BuildContext context) {
    List<String> autoNames = [];
    for (PathPlannerAuto auto in _autos) {
      autoNames.add(auto.name);
    }

    if (autoNames.contains(newName)) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Unable to Rename'),
              content: Text('The file "$newName.auto" already exists'),
              actions: [
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('OK'),
                ),
              ],
            );
          });
    } else {
      setState(() {
        _autos[autoIdx].rename(newName);
      });
    }
  }
}
