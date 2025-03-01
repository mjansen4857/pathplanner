import 'dart:async';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:path/path.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/commands/command_groups.dart';
import 'package:pathplanner/commands/named_command.dart';
import 'package:pathplanner/pages/auto_editor_page.dart';
import 'package:pathplanner/pages/choreo_path_editor_page.dart';
import 'package:pathplanner/pages/path_editor_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/choreo_path.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/dialogs/management_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'package:watcher/watcher.dart';

class ProjectPage extends StatefulWidget {
  static Set<String> events = {};

  final SharedPreferences prefs;
  final FieldImage fieldImage;
  final Directory pathplannerDirectory;
  final Directory choreoDirectory;
  final FileSystem fs;
  final ChangeStack undoStack;
  final bool shortcuts;
  final PPLibTelemetry? telemetry;
  final bool hotReload;
  final VoidCallback? onFoldersChanged;
  final bool simulatePath;
  final bool watchChorDir;

  // Stupid workaround to get when settings are updated
  static bool settingsUpdated = false;

  const ProjectPage({
    super.key,
    required this.prefs,
    required this.fieldImage,
    required this.pathplannerDirectory,
    required this.choreoDirectory,
    required this.fs,
    required this.undoStack,
    this.shortcuts = true,
    this.telemetry,
    this.hotReload = false,
    this.onFoldersChanged,
    this.simulatePath = false,
    this.watchChorDir = false,
  });

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final MultiSplitViewController _controller = MultiSplitViewController();
  List<PathPlannerPath> _paths = [];
  List<String> _pathFolders = [];
  List<PathPlannerAuto> _autos = [];
  List<String> _autoFolders = [];
  List<ChoreoPath> _choreoPaths = [];
  late Directory _pathsDirectory;
  late Directory _autosDirectory;
  late Directory _choreoDirectory;
  late String _pathSortValue;
  late String _autoSortValue;
  late bool _pathsCompact;
  late bool _autosCompact;
  late int _pathGridCount;
  late int _autosGridCount;
  DirectoryWatcher? _chorWatcher;
  StreamSubscription<WatchEvent>? _chorWatcherSub;

  String _pathSearchQuery = '';
  String _autoSearchQuery = '';

  late TextEditingController _pathSearchController;
  late TextEditingController _autoSearchController;

  bool _loading = true;

  String? _pathFolder;
  String? _autoFolder;
  bool _inChoreoFolder = false;

  final GlobalKey _addAutoKey = GlobalKey();

  FileSystem get fs => widget.fs;

  @override
  void initState() {
    super.initState();

    _pathSearchController = TextEditingController();
    _autoSearchController = TextEditingController();

    double leftWeight =
        widget.prefs.getDouble(PrefsKeys.projectLeftWeight) ?? Defaults.projectLeftWeight;
    _controller.areas = [
      Area(
        weight: leftWeight,
        minimalWeight: 0.33,
      ),
      Area(
        weight: 1.0 - leftWeight,
        minimalWeight: 0.33,
      ),
    ];

    _pathSortValue = widget.prefs.getString(PrefsKeys.pathSortOption) ?? Defaults.pathSortOption;
    _autoSortValue = widget.prefs.getString(PrefsKeys.autoSortOption) ?? Defaults.autoSortOption;
    _pathsCompact = widget.prefs.getBool(PrefsKeys.pathsCompactView) ?? Defaults.pathsCompactView;
    _autosCompact = widget.prefs.getBool(PrefsKeys.autosCompactView) ?? Defaults.autosCompactView;

    _pathGridCount = _getCrossAxisCountForWeight(leftWeight);
    _autosGridCount = _getCrossAxisCountForWeight(1.0 - leftWeight);

    _pathFolders = widget.prefs.getStringList(PrefsKeys.pathFolders) ?? Defaults.pathFolders;
    _autoFolders = widget.prefs.getStringList(PrefsKeys.autoFolders) ?? Defaults.autoFolders;

    // Set up choreo directory watcher
    if (widget.watchChorDir) {
      widget.choreoDirectory.exists().then((value) {
        if (value) {
          _chorWatcher = DirectoryWatcher(widget.choreoDirectory.path,
              pollingDelay: const Duration(seconds: 1));

          Timer? loadTimer;

          _chorWatcherSub = _chorWatcher!.events.listen((event) {
            loadTimer?.cancel();
            loadTimer = Timer(const Duration(milliseconds: 500), () {
              _load();
              if (mounted) {
                if (Navigator.of(this.context).canPop()) {
                  // We might have a path or auto open, close it
                  Navigator.of(this.context).pop();
                }

                ScaffoldMessenger.of(this.context)
                    .showSnackBar(const SnackBar(content: Text('Reloaded Choreo paths')));
              }
            });
          });
        }
      });
    }

    _load();
  }

  @override
  void dispose() {
    _chorWatcherSub?.cancel();

    _pathSearchController.dispose();
    _autoSearchController.dispose();
    super.dispose();
  }

  void _load() async {
    // Make sure dirs exist
    _pathsDirectory = fs.directory(join(widget.pathplannerDirectory.path, 'paths'));
    _pathsDirectory.createSync(recursive: true);
    _autosDirectory = fs.directory(join(widget.pathplannerDirectory.path, 'autos'));
    _autosDirectory.createSync(recursive: true);
    _choreoDirectory = fs.directory(widget.choreoDirectory);

    var paths = await PathPlannerPath.loadAllPathsInDir(_pathsDirectory.path, fs);
    var autos = await PathPlannerAuto.loadAllAutosInDir(_autosDirectory.path, fs);
    List<ChoreoPath> choreoPaths = await ChoreoPath.loadAllPathsInDir(_choreoDirectory.path, fs);

    List<String> allPathNames = [];
    for (PathPlannerPath path in paths) {
      allPathNames.add(path.name);
    }

    List<String> allChoreoPathNames = [];
    for (ChoreoPath path in choreoPaths) {
      allChoreoPathNames.add(path.name);
    }

    for (int i = 0; i < paths.length; i++) {
      if (!_pathFolders.contains(paths[i].folder)) {
        paths[i].folder = null;
      }
    }
    for (int i = 0; i < autos.length; i++) {
      if (!_autoFolders.contains(autos[i].folder)) {
        autos[i].folder = null;
      }

      autos[i].handleMissingPaths(autos[i].choreoAuto ? allChoreoPathNames : allPathNames);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _paths = paths;
      _autos = autos;
      _choreoPaths = choreoPaths;
      _pathFolder = null;
      _autoFolder = null;
      _inChoreoFolder = false;

      if (_paths.isEmpty) {
        _paths.add(PathPlannerPath.defaultPath(
          pathDir: _pathsDirectory.path,
          name: 'Example Path',
          fs: fs,
          constraints: _getDefaultConstraints(),
        ));
      }

      _sortPaths(_pathSortValue);
      _sortAutos(_autoSortValue);

      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Update _pathSortValue from shared preferences
    _pathSortValue = widget.prefs.getString(PrefsKeys.pathSortOption) ?? Defaults.pathSortOption;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Stupid workaround but it works
    if (ProjectPage.settingsUpdated) {
      PathConstraints defaultConstraints = _getDefaultConstraints();

      for (PathPlannerPath path in _paths) {
        if (path.useDefaultConstraints) {
          PathConstraints cloned = defaultConstraints.clone();
          cloned.unlimited = path.globalConstraints.unlimited;
          path.globalConstraints = cloned;
          path.generateAndSavePath();
        }
      }

      ProjectPage.settingsUpdated = false;
    }

    return Stack(
      children: [
        Container(
          color: colorScheme.surfaceTint.withAlpha(15),
          child: MultiSplitViewTheme(
            data: MultiSplitViewThemeData(
              dividerPainter: DividerPainters.grooved1(
                color: colorScheme.surfaceContainerHighest,
                highlightedColor: colorScheme.primary,
              ),
            ),
            child: MultiSplitView(
              axis: Axis.horizontal,
              controller: _controller,
              onWeightChange: () {
                setState(() {
                  _pathGridCount = _getCrossAxisCountForWeight(_controller.areas[0].weight!);
                  _autosGridCount = _getCrossAxisCountForWeight(1.0 - _controller.areas[0].weight!);
                });
                widget.prefs.setDouble(PrefsKeys.projectLeftWeight,
                    _controller.areas[0].weight ?? Defaults.projectLeftWeight);
              },
              children: [
                _buildPathsGrid(context),
                _buildAutosGrid(context),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              clipBehavior: Clip.antiAlias,
              tooltip: 'Manage Events & Linked Waypoints',
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              onPressed: () => showDialog(
                context: context,
                builder: (BuildContext context) => ManagementDialog(
                  onEventRenamed: (String oldName, String newName) {
                    setState(() {
                      for (PathPlannerPath path in _paths) {
                        for (EventMarker m in path.eventMarkers) {
                          if (m.command != null) {
                            _replaceNamedCommand(oldName, newName, m.command!);
                          }
                          if (m.name == oldName) {
                            m.name = newName;
                          }
                        }
                        path.generateAndSavePath();
                      }

                      for (PathPlannerAuto auto in _autos) {
                        for (Command cmd in auto.sequence.commands) {
                          _replaceNamedCommand(oldName, newName, cmd);
                        }
                        auto.saveFile();
                      }
                    });
                  },
                  onEventDeleted: (String name) {
                    setState(() {
                      for (PathPlannerPath path in _paths) {
                        for (EventMarker m in path.eventMarkers) {
                          if (m.command != null) {
                            _replaceNamedCommand(name, null, m.command!);
                          }
                          if (m.name == name) {
                            m.name = '';
                          }
                        }
                        path.generateAndSavePath();
                      }

                      for (PathPlannerAuto auto in _autos) {
                        for (Command cmd in auto.sequence.commands) {
                          _replaceNamedCommand(name, null, cmd);
                        }
                        auto.saveFile();
                      }
                    });
                  },
                  onLinkedRenamed: (String oldName, String newName) {
                    setState(() {
                      Pose2d? pose = Waypoint.linked.remove(oldName);

                      if (pose != null) {
                        Waypoint.linked[newName] = pose;

                        for (PathPlannerPath path in _paths) {
                          bool changed = false;

                          for (Waypoint w in path.waypoints) {
                            if (w.linkedName == oldName) {
                              w.linkedName = newName;
                              changed = true;
                            }
                          }

                          if (changed) {
                            path.generateAndSavePath();
                          }
                        }
                      }
                    });
                  },
                  onLinkedDeleted: (String name) {
                    setState(() {
                      Waypoint.linked.remove(name);

                      for (PathPlannerPath path in _paths) {
                        bool changed = false;

                        for (Waypoint w in path.waypoints) {
                          if (w.linkedName == name) {
                            w.linkedName = null;
                            changed = true;
                          }
                        }

                        if (changed) {
                          path.generateAndSavePath();
                        }
                      }
                    });
                  },
                ),
              ),
              // Dumb hack to get an elevation surface tint
              child: Stack(
                children: [
                  Container(
                    color: colorScheme.surfaceTint.withAlpha(30),
                  ),
                  const Center(child: Icon(Icons.edit_note_rounded)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _replaceNamedCommand(String originalName, String? newName, Command command) {
    if (command is NamedCommand && command.name == originalName) {
      command.name = newName;
    } else if (command is CommandGroup) {
      for (Command cmd in command.commands) {
        _replaceNamedCommand(originalName, newName, cmd);
      }
    }
  }

  Widget _buildPathsGrid(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (_inChoreoFolder) {
      return Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
        child: Card(
          elevation: 0.0,
          margin: const EdgeInsets.all(0),
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOptionsRow(
                  sortValue: _pathSortValue,
                  viewValue: _pathsCompact,
                  onSortChanged: (value) async {
                    await widget.prefs.setString(PrefsKeys.pathSortOption, value);
                    setState(() {
                      _pathSortValue = value;
                      _sortPaths(_pathSortValue);
                    });
                  },
                  onViewChanged: (value) {
                    widget.prefs.setBool(PrefsKeys.pathsCompactView, value);
                    setState(() {
                      _pathsCompact = value;
                    });
                  },
                  onSearchChanged: (value) {
                    setState(() {
                      _pathSearchQuery = value;
                    });
                  },
                  searchController: _pathSearchController,
                  onAddFolder: () {
                    String folderName = 'New Folder';
                    while (_pathFolders.contains(folderName)) {
                      folderName = 'New $folderName';
                    }

                    setState(() {
                      _pathFolders.add(folderName);
                      _sortPaths(_pathSortValue);
                    });
                    widget.prefs.setStringList(PrefsKeys.pathFolders, _pathFolders);
                    widget.onFoldersChanged?.call();
                  },
                  onAddItem: () {
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
                        fs: fs,
                        folder: _pathFolder,
                        constraints: _getDefaultConstraints(),
                      ));
                      _sortPaths(_pathSortValue);
                    });
                  },
                  isPathsView: true,
                ),
                GridView.count(
                  crossAxisCount: _pathGridCount,
                  childAspectRatio: 5.5,
                  shrinkWrap: true,
                  children: [
                    Card(
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _inChoreoFolder = false;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_move_rtl_outlined),
                              SizedBox(width: 12),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Root Folder',
                                    style: TextStyle(
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: _pathsCompact ? _pathGridCount + 1 : _pathGridCount,
                    childAspectRatio: _pathsCompact ? 2.5 : 1.55,
                    children: [
                      for (int i = 0; i < _choreoPaths.length; i++)
                        _buildChoreoPathCard(i, context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 8.0),
      child: Card(
        elevation: 0.0,
        margin: const EdgeInsets.all(0),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildOptionsRow(
                sortValue: _pathSortValue,
                viewValue: _pathsCompact,
                onSortChanged: (value) {
                  widget.prefs.setString(PrefsKeys.pathSortOption, value);
                  setState(() {
                    _pathSortValue = value;
                    _sortPaths(_pathSortValue);
                  });
                },
                onViewChanged: (value) {
                  widget.prefs.setBool(PrefsKeys.pathsCompactView, value);
                  setState(() {
                    _pathsCompact = value;
                  });
                },
                onSearchChanged: (value) {
                  setState(() {
                    _pathSearchQuery = value;
                  });
                },
                searchController: _pathSearchController,
                onAddFolder: () {
                  String folderName = 'New Folder';
                  while (_pathFolders.contains(folderName)) {
                    folderName = 'New $folderName';
                  }

                  setState(() {
                    _pathFolders.add(folderName);
                    _sortPaths(_pathSortValue);
                  });
                  widget.prefs.setStringList(PrefsKeys.pathFolders, _pathFolders);
                  widget.onFoldersChanged?.call();
                },
                onAddItem: () {
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
                      fs: fs,
                      folder: _pathFolder,
                      constraints: _getDefaultConstraints(),
                    ));
                    _sortPaths(_pathSortValue);
                  });
                },
                isPathsView: true,
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ConditionalWidget(
                      condition: _pathFolder == null,
                      falseChild: GridView.count(
                        crossAxisCount: _pathGridCount,
                        childAspectRatio: 5.5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          DragTarget<PathPlannerPath>(
                            onAcceptWithDetails: (details) {
                              setState(() {
                                details.data.folder = null;
                                details.data.generateAndSavePath();
                              });
                            },
                            builder: (context, candidates, rejects) {
                              ColorScheme colorScheme = Theme.of(context).colorScheme;
                              return Card(
                                elevation: 2,
                                color: candidates.isNotEmpty
                                    ? colorScheme.primary
                                    : colorScheme.surface,
                                surfaceTintColor: colorScheme.surfaceTint,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      _pathFolder = null;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.drive_file_move_rtl_outlined,
                                          color:
                                              candidates.isNotEmpty ? colorScheme.onPrimary : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Root Folder',
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: candidates.isNotEmpty
                                                    ? colorScheme.onPrimary
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      trueChild: GridView.count(
                        crossAxisCount: _pathGridCount,
                        childAspectRatio: 5.5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          if (_choreoPaths.isNotEmpty)
                            Card(
                              elevation: 2,
                              color: colorScheme.surface,
                              surfaceTintColor: colorScheme.surfaceTint,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    _inChoreoFolder = true;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.folder_outlined),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Choreo Paths',
                                            style: TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          for (int i = 0; i < _pathFolders.length; i++)
                            DragTarget<PathPlannerPath>(
                              onAcceptWithDetails: (details) {
                                setState(() {
                                  details.data.folder = _pathFolders[i];
                                  details.data.generateAndSavePath();
                                });
                              },
                              builder: (context, candidates, rejects) {
                                ColorScheme colorScheme = Theme.of(context).colorScheme;
                                return Card(
                                  elevation: 2,
                                  color: candidates.isNotEmpty
                                      ? colorScheme.primary
                                      : colorScheme.surface,
                                  surfaceTintColor: colorScheme.surfaceTint,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        _pathFolder = _pathFolders[i];
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.folder_outlined,
                                            color: candidates.isNotEmpty
                                                ? colorScheme.onPrimary
                                                : null,
                                          ),
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: RenamableTitle(
                                                title: _pathFolders[i],
                                                textStyle: TextStyle(
                                                  fontSize: 20,
                                                  color: candidates.isNotEmpty
                                                      ? colorScheme.onPrimary
                                                      : null,
                                                ),
                                                onRename: (newName) {
                                                  if (newName != _pathFolders[i]) {
                                                    if (_pathFolders.contains(newName)) {
                                                      showDialog(
                                                          context: context,
                                                          builder: (BuildContext context) {
                                                            ColorScheme colorScheme =
                                                                Theme.of(context).colorScheme;
                                                            return AlertDialog(
                                                              backgroundColor: colorScheme.surface,
                                                              surfaceTintColor:
                                                                  colorScheme.surfaceTint,
                                                              title: const Text('Unable to Rename'),
                                                              content: Text(
                                                                  'The folder "$newName" already exists'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      Navigator.of(context).pop,
                                                                  child: const Text('OK'),
                                                                ),
                                                              ],
                                                            );
                                                          });
                                                    } else {
                                                      setState(() {
                                                        for (PathPlannerPath path in _paths) {
                                                          if (path.folder == _pathFolders[i]) {
                                                            path.folder = newName;
                                                            path.generateAndSavePath();
                                                          }
                                                        }
                                                        _pathFolders[i] = newName;
                                                      });
                                                      widget.prefs.setStringList(
                                                          PrefsKeys.pathFolders, _pathFolders);
                                                      widget.onFoldersChanged?.call();
                                                    }
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    if (_pathFolders.isNotEmpty || _choreoPaths.isNotEmpty)
                      const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: _pathsCompact ? _pathGridCount + 1 : _pathGridCount,
                      childAspectRatio: _pathsCompact ? 2.5 : 1.55,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        for (int i = 0; i < _paths.length; i++)
                          if (_paths[i].folder == _pathFolder &&
                              _paths[i].name.toLowerCase().contains(_pathSearchQuery.toLowerCase()))
                            _buildPathCard(i, context),
                      ],
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

  Widget _buildPathCard(int i, BuildContext context) {
    final pathCard = ProjectItemCard(
      name: _paths[i].name,
      compact: _pathsCompact,
      fieldImage: widget.fieldImage,
      paths: [_paths[i].pathPositions],
      warningMessage: _paths[i].hasEmptyNamedCommand()
          ? 'Contains a NamedCommand that does not have a command selected'
          : null,
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
          _sortPaths(_pathSortValue);
        });
      },
      onReverse: () {
        List<String> pathNames = [];
        for (PathPlannerPath path in _paths) {
          pathNames.add(path.name);
        }
        String pathName = 'Reverse of ${_paths[i].name}';
        while (pathNames.contains(pathName)) {
          pathName = 'Reverse of $pathName';
        }

        setState(() {
          _paths.add(_paths[i].reverse(pathName));
          _sortPaths(_pathSortValue);
        });
      },
      onReverseH: () {
        List<String> pathNames = [];
        for (PathPlannerPath path in _paths) {
          pathNames.add(path.name);
        }
        String pathName = 'ReverseH of ${_paths[i].name}';
        while (pathNames.contains(pathName)) {
          pathName = 'ReverseH of $pathName';
        }

        setState(() {
          _paths.add(_paths[i].reverseH(pathName));
          _sortPaths(_pathSortValue);
        });
      },
      onDeleted: () {
        _paths[i].deletePath();
        setState(() {
          _paths.removeAt(i);
        });

        List<String> allPathNames = _paths.map((e) => e.name).toList();
        for (PathPlannerAuto auto in _autos) {
          if (!auto.choreoAuto) {
            auto.handleMissingPaths(allPathNames);
          }
        }
      },
      onRenamed: (value) => _renamePath(_paths[i], value, context),
      onOpened: () => _openPath(_paths[i]),
    );

    return LayoutBuilder(builder: (context, constraints) {
      return Draggable<PathPlannerPath>(
        data: _paths[i],
        feedback: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Opacity(
            opacity: 0.8,
            child: pathCard,
          ),
        ),
        childWhenDragging: Container(),
        child: pathCard,
      );
    });
  }

  Widget _buildChoreoPathCard(int i, BuildContext context) {
    final pathCard = ProjectItemCard(
      name: _choreoPaths[i].name,
      compact: _pathsCompact,
      fieldImage: widget.fieldImage,
      showOptions: false,
      paths: [_choreoPaths[i].pathPositions],
      choreoItem: true,
      onOpened: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChoreoPathEditorPage(
              prefs: widget.prefs,
              path: _choreoPaths[i],
              fieldImage: widget.fieldImage,
              undoStack: widget.undoStack,
              shortcuts: widget.shortcuts,
              simulatePath: widget.simulatePath,
            ),
          ),
        );
      },
    );

    return LayoutBuilder(builder: (context, constraints) {
      return Draggable<ChoreoPath>(
        data: _choreoPaths[i],
        feedback: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Opacity(
            opacity: 0.8,
            child: pathCard,
          ),
        ),
        childWhenDragging: Container(),
        child: pathCard,
      );
    });
  }

  void _openPath(PathPlannerPath path) async {
    await Navigator.push(
      this.context,
      MaterialPageRoute(
        builder: (context) => PathEditorPage(
          prefs: widget.prefs,
          path: path,
          fieldImage: widget.fieldImage,
          undoStack: widget.undoStack,
          onRenamed: (value) => _renamePath(path, value, context),
          shortcuts: widget.shortcuts,
          telemetry: widget.telemetry,
          hotReload: widget.hotReload,
          simulatePath: widget.simulatePath,
          onPathChanged: () {
            // Update the linked rotation for the start/end states
            if (path.waypoints.first.linkedName != null) {
              Waypoint.linked[path.waypoints.first.linkedName!] =
                  Pose2d(path.waypoints.first.anchor, path.idealStartingState.rotation);
            }
            if (path.waypoints.last.linkedName != null) {
              Waypoint.linked[path.waypoints.last.linkedName!] =
                  Pose2d(path.waypoints.last.anchor, path.goalEndState.rotation);
            }

            // Make sure all paths with linked waypoints are updated
            for (PathPlannerPath p in _paths) {
              bool changed = false;

              for (int i = 0; i < p.waypoints.length; i++) {
                Waypoint w = p.waypoints[i];
                if (w.linkedName != null && Waypoint.linked.containsKey(w.linkedName!)) {
                  Pose2d link = Waypoint.linked[w.linkedName!]!;

                  if (link.translation.getDistance(w.anchor) >= 0.01) {
                    w.move(link.translation.x, link.translation.y);
                    changed = true;
                  }

                  if (i == 0 &&
                      (link.rotation - p.idealStartingState.rotation).degrees.abs() > 0.01) {
                    p.idealStartingState.rotation = link.rotation;
                    changed = true;
                  } else if (i == p.waypoints.length - 1 &&
                      (link.rotation - p.goalEndState.rotation).degrees.abs() > 0.01) {
                    p.goalEndState.rotation = link.rotation;
                    changed = true;
                  }
                }
              }

              if (changed) {
                p.generateAndSavePath();

                if (widget.hotReload) {
                  widget.telemetry?.hotReloadPath(p);
                }
              }
            }
          },
        ),
      ),
    );

    setState(() {
      _sortPaths(_pathSortValue);
    });
  }

  void _renamePath(PathPlannerPath path, String newName, BuildContext context) {
    List<String> pathNames = [];
    for (PathPlannerPath p in _paths) {
      pathNames.add(p.name);
    }

    if (pathNames.contains(newName)) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            ColorScheme colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
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
      String oldName = path.name;
      setState(() {
        path.renamePath(newName);
        for (PathPlannerAuto auto in _autos) {
          auto.updatePathName(oldName, newName);
        }
        _sortPaths(_pathSortValue);
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
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0, top: 8.0),
      child: Card(
        elevation: 0.0,
        margin: const EdgeInsets.all(0),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildOptionsRow(
                sortValue: _autoSortValue,
                viewValue: _autosCompact,
                onSortChanged: (value) {
                  widget.prefs.setString(PrefsKeys.autoSortOption, value);
                  setState(() {
                    _autoSortValue = value;
                    _sortAutos(_autoSortValue);
                  });
                },
                onViewChanged: (value) {
                  widget.prefs.setBool(PrefsKeys.autosCompactView, value);
                  setState(() {
                    _autosCompact = value;
                  });
                },
                onSearchChanged: (value) {
                  setState(() {
                    _autoSearchQuery = value;
                  });
                },
                searchController: _autoSearchController,
                onAddFolder: () {
                  String folderName = 'New Folder';
                  while (_autoFolders.contains(folderName)) {
                    folderName = 'New $folderName';
                  }

                  setState(() {
                    _autoFolders.add(folderName);
                    _sortAutos(_autoSortValue);
                  });
                  widget.prefs.setStringList(PrefsKeys.autoFolders, _autoFolders);
                  widget.onFoldersChanged?.call();
                },
                onAddItem: () {
                  if (_choreoPaths.isNotEmpty) {
                    final RenderBox renderBox =
                        _addAutoKey.currentContext?.findRenderObject() as RenderBox;
                    final Size size = renderBox.size;
                    final Offset offset = renderBox.localToGlobal(Offset.zero);

                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        offset.dx,
                        offset.dy + size.height,
                        offset.dx + size.width,
                        offset.dy + size.height,
                      ),
                      items: [
                        PopupMenuItem(
                          child: const Text('New PathPlanner Auto'),
                          onTap: () => _createNewAuto(),
                        ),
                        PopupMenuItem(
                          child: const Text('New Choreo Auto'),
                          onTap: () => _createNewAuto(choreo: true),
                        ),
                      ],
                    );
                  } else {
                    _createNewAuto();
                  }
                },
                isPathsView: false,
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ConditionalWidget(
                      condition: _autoFolder == null,
                      falseChild: GridView.count(
                        crossAxisCount: _autosGridCount,
                        childAspectRatio: 5.5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          DragTarget<PathPlannerAuto>(
                            onAcceptWithDetails: (details) {
                              setState(() {
                                details.data.folder = null;
                                details.data.saveFile();
                              });
                            },
                            builder: (context, candidates, rejects) {
                              ColorScheme colorScheme = Theme.of(context).colorScheme;
                              return Card(
                                elevation: 2,
                                color: candidates.isNotEmpty
                                    ? colorScheme.primary
                                    : colorScheme.surface,
                                surfaceTintColor: colorScheme.surfaceTint,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      _autoFolder = null;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.drive_file_move_rtl_outlined,
                                          color:
                                              candidates.isNotEmpty ? colorScheme.onPrimary : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Root Folder',
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: candidates.isNotEmpty
                                                    ? colorScheme.onPrimary
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      trueChild: GridView.count(
                        crossAxisCount: _autosGridCount,
                        childAspectRatio: 5.5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (int i = 0; i < _autoFolders.length; i++)
                            DragTarget<PathPlannerAuto>(
                              onAcceptWithDetails: (details) {
                                setState(() {
                                  details.data.folder = _autoFolders[i];
                                  details.data.saveFile();
                                });
                              },
                              builder: (context, candidates, rejects) {
                                ColorScheme colorScheme = Theme.of(context).colorScheme;
                                return Card(
                                  elevation: 2,
                                  color: candidates.isNotEmpty
                                      ? colorScheme.primary
                                      : colorScheme.surface,
                                  surfaceTintColor: colorScheme.surfaceTint,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        _autoFolder = _autoFolders[i];
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.folder_outlined,
                                            color: candidates.isNotEmpty
                                                ? colorScheme.onPrimary
                                                : null,
                                          ),
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: RenamableTitle(
                                                title: _autoFolders[i],
                                                textStyle: TextStyle(
                                                  fontSize: 20,
                                                  color: candidates.isNotEmpty
                                                      ? colorScheme.onPrimary
                                                      : null,
                                                ),
                                                onRename: (newName) {
                                                  if (newName != _autoFolders[i]) {
                                                    if (_autoFolders.contains(newName)) {
                                                      showDialog(
                                                          context: context,
                                                          builder: (BuildContext context) {
                                                            ColorScheme colorScheme =
                                                                Theme.of(context).colorScheme;
                                                            return AlertDialog(
                                                              backgroundColor: colorScheme.surface,
                                                              surfaceTintColor:
                                                                  colorScheme.surfaceTint,
                                                              title: const Text('Unable to Rename'),
                                                              content: Text(
                                                                  'The folder "$newName" already exists'),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      Navigator.of(context).pop,
                                                                  child: const Text('OK'),
                                                                ),
                                                              ],
                                                            );
                                                          });
                                                    } else {
                                                      setState(() {
                                                        for (PathPlannerAuto auto in _autos) {
                                                          if (auto.folder == _autoFolders[i]) {
                                                            auto.folder = newName;
                                                            auto.saveFile();
                                                          }
                                                        }
                                                        _autoFolders[i] = newName;
                                                      });
                                                      widget.prefs.setStringList(
                                                          PrefsKeys.autoFolders, _autoFolders);
                                                      widget.onFoldersChanged?.call();
                                                    }
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    if (_autoFolders.isNotEmpty) const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: _autosCompact ? _autosGridCount + 1 : _autosGridCount,
                      childAspectRatio: _autosCompact ? 2.5 : 1.55,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: [
                        for (int i = 0; i < _autos.length; i++)
                          if (_autos[i].folder == _autoFolder &&
                              _autos[i].name.toLowerCase().contains(_autoSearchQuery.toLowerCase()))
                            _buildAutoCard(i, context),
                      ],
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

  Widget _buildAutoCard(int i, BuildContext context) {
    String? warningMessage;

    if (_autos[i].hasEmptyPathCommands()) {
      warningMessage = 'Contains a FollowPathCommand that does not have a path selected';
    } else if (_autos[i].hasEmptyNamedCommand()) {
      warningMessage = 'Contains a NamedCommand that does not have a command selected';
    }

    final autoCard = ProjectItemCard(
      name: _autos[i].name,
      compact: _autosCompact,
      fieldImage: widget.fieldImage,
      choreoItem: _autos[i].choreoAuto,
      paths: _autos[i].choreoAuto
          ? [
              for (ChoreoPath path in _getChoreoPathsFromNames(_autos[i].getAllPathNames()))
                path.pathPositions,
            ]
          : [
              for (PathPlannerPath path in _getPathsFromNames(_autos[i].getAllPathNames()))
                path.pathPositions,
            ],
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
          _sortAutos(_autoSortValue);
        });
      },
      onReverse: () {
        List<String> autoNames = [];
        for (PathPlannerAuto auto in _autos) {
          autoNames.add(auto.name);
        }
        String autoName = 'Reverse of ${_autos[i].name}';
        while (autoNames.contains(autoName)) {
          autoName = 'Reverse of $autoName';
        }

        setState(() {
          _autos.add(_autos[i].reverse(autoName));
          _sortAutos(_autoSortValue);
        });
      },
      onDeleted: () {
        _autos[i].delete();
        setState(() {
          _autos.removeAt(i);
        });
      },
      onRenamed: (value) => _renameAuto(i, value, context),
      onOpened: () async {
        String? pathNameToOpen = await Navigator.push<String?>(
          context,
          MaterialPageRoute(
            builder: (context) => AutoEditorPage(
              prefs: widget.prefs,
              auto: _autos[i],
              allPaths: _paths,
              allChoreoPaths: _choreoPaths,
              undoStack: widget.undoStack,
              allPathNames: _autos[i].choreoAuto
                  ? _choreoPaths.map((e) => e.name).toList()
                  : _paths.map((e) => e.name).toList(),
              fieldImage: widget.fieldImage,
              onRenamed: (value) => _renameAuto(i, value, context),
              shortcuts: widget.shortcuts,
              telemetry: widget.telemetry,
              hotReload: widget.hotReload,
            ),
          ),
        );
        setState(() {
          _sortAutos(_autoSortValue);
        });

        if (pathNameToOpen != null) {
          final pathToOpen = _paths.firstWhereOrNull((p) => p.name == pathNameToOpen);
          if (pathToOpen != null) {
            _openPath(pathToOpen);
          }
        }
      },
      warningMessage: warningMessage,
    );

    return LayoutBuilder(builder: (context, constraints) {
      return Draggable<PathPlannerAuto>(
        data: _autos[i],
        feedback: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Opacity(
            opacity: 0.8,
            child: autoCard,
          ),
        ),
        childWhenDragging: Container(),
        child: autoCard,
      );
    });
  }

  Widget _buildOptionsRow({
    required String sortValue,
    required bool viewValue,
    required ValueChanged<String> onSortChanged,
    required ValueChanged<bool> onViewChanged,
    required ValueChanged<String> onSearchChanged,
    required TextEditingController searchController,
    required VoidCallback onAddFolder,
    required VoidCallback onAddItem,
    required bool isPathsView,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(children: [
        Row(
          children: [
            _buildViewButton(
              viewValue: viewValue,
              onViewChanged: onViewChanged,
            ),
            _buildSortButton(
              sortValue: sortValue,
              onSortChanged: onSortChanged,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSearchBar(
                isPathsView: isPathsView,
                onChanged: onSearchChanged,
                controller: searchController,
              ),
            ),
            const SizedBox(width: 14),
            _buildFolderButton(
              isPathsView: isPathsView,
              onAddFolder: onAddFolder,
              onDeleteFolder: () {
                showDialog(
                  context: this.context,
                  builder: (context) {
                    ColorScheme colorScheme = Theme.of(context).colorScheme;
                    return AlertDialog(
                      backgroundColor: colorScheme.surface,
                      surfaceTintColor: colorScheme.surfaceTint,
                      title: const Text('Delete Folder'),
                      content: SizedBox(
                        width: 400,
                        child: Text(
                          'Are you sure you want to delete the folder "${isPathsView ? _pathFolder : _autoFolder}"?\n\nThis will also delete all ${isPathsView ? "paths" : "autos"} within the folder. This cannot be undone.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: Navigator.of(context).pop,
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();

                            if (isPathsView) {
                              for (int p = 0; p < _paths.length; p++) {
                                if (_paths[p].folder == _pathFolder) {
                                  _paths[p].deletePath();
                                }
                              }

                              setState(() {
                                _paths.removeWhere((path) => path.folder == _pathFolder);
                                _pathFolders.remove(_pathFolder);
                                _pathFolder = null;
                              });
                              widget.prefs.setStringList(PrefsKeys.pathFolders, _pathFolders);
                            } else {
                              for (int a = 0; a < _autos.length; a++) {
                                if (_autos[a].folder == _autoFolder) {
                                  _autos[a].delete();
                                }
                              }

                              setState(() {
                                _autos.removeWhere((auto) => auto.folder == _autoFolder);
                                _autoFolders.remove(_autoFolder);
                                _autoFolder = null;
                              });
                              widget.prefs.setStringList(PrefsKeys.autoFolders, _autoFolders);
                            }
                            widget.onFoldersChanged?.call();
                          },
                          child: const Text('DELETE'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            _buildAddButton(
              isPathsView: isPathsView,
              onAddItem: onAddItem,
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _buildViewButton({
    required bool viewValue,
    required ValueChanged<bool> onViewChanged,
  }) {
    return PopupMenuButton<bool>(
      initialValue: viewValue,
      tooltip: 'View options',
      icon: Icon(viewValue ? Icons.view_list_rounded : Icons.grid_view_rounded),
      itemBuilder: (context) => const [
        PopupMenuItem(value: false, child: Text('Default')),
        PopupMenuItem(value: true, child: Text('Compact')),
      ],
      onSelected: onViewChanged,
    );
  }

  Widget _buildSortButton({
    required String sortValue,
    required ValueChanged<String> onSortChanged,
  }) {
    return PopupMenuButton<String>(
      initialValue: sortValue,
      tooltip: 'Sort options',
      icon: const Icon(Icons.sort_rounded),
      itemBuilder: (context) => _sortOptions(),
      onSelected: onSortChanged,
    );
  }

  Widget _buildFolderButton({
    required bool isPathsView,
    required VoidCallback onAddFolder,
    required VoidCallback onDeleteFolder,
  }) {
    final bool isRootFolder = isPathsView ? _pathFolder == null : _autoFolder == null;

    return IconButton.filledTonal(
      icon: Icon(isRootFolder ? Icons.create_new_folder_outlined : Icons.delete_forever_rounded),
      tooltip: isRootFolder
          ? 'Add new folder'
          : isPathsView
              ? 'Delete path folder'
              : 'Delete auto folder',
      onPressed: () {
        if (isRootFolder) {
          onAddFolder();
        } else {
          onDeleteFolder();
        }
      },
    );
  }

  Widget _buildAddButton({
    required bool isPathsView,
    required VoidCallback onAddItem,
  }) {
    if (!isPathsView) {
      return Tooltip(
        message: 'Add new auto',
        waitDuration: const Duration(seconds: 1),
        child: IconButton.filled(
          key: _addAutoKey,
          onPressed: () {
            if (_choreoPaths.isNotEmpty) {
              final RenderBox renderBox =
                  _addAutoKey.currentContext?.findRenderObject() as RenderBox;
              final Size size = renderBox.size;
              final Offset offset = renderBox.localToGlobal(Offset.zero);
              showMenu(
                context: this.context,
                position: RelativeRect.fromLTRB(
                  offset.dx,
                  offset.dy + size.height,
                  offset.dx + size.width,
                  offset.dy + size.height,
                ),
                items: [
                  PopupMenuItem(
                    child: const Text('New PathPlanner Auto'),
                    onTap: () => _createNewAuto(),
                  ),
                  PopupMenuItem(
                    child: const Text('New Choreo Auto'),
                    onTap: () => _createNewAuto(choreo: true),
                  ),
                ],
              );
            } else {
              _createNewAuto();
            }
          },
          icon: const Icon(Icons.add_rounded),
        ),
      );
    } else {
      return IconButton.filled(
        tooltip: 'Add new path',
        icon: const Icon(Icons.add_rounded),
        onPressed: onAddItem,
      );
    }
  }

  void _createNewAuto({bool choreo = false}) {
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
        fs: fs,
        folder: _autoFolder,
        choreoAuto: choreo,
      ));
      _sortAutos(_autoSortValue);
    });
  }

  Widget _buildSearchBar({
    required bool isPathsView,
    required ValueChanged<String> onChanged,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search for ${isPathsView ? "Paths..." : "Autos..."}',
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Icon(Icons.search_rounded),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
      onChanged: (value) {
        // Debounce the search to avoid freezing
        Future.delayed(const Duration(milliseconds: 300), () {
          if (value == controller.text) {
            onChanged(value);
          }
        });
      },
    );
  }

  List<PathPlannerPath> _getPathsFromNames(List<String> names) {
    List<PathPlannerPath> paths = [];
    for (String name in names) {
      List<PathPlannerPath> matched = _paths.where((path) => path.name == name).toList();
      if (matched.isNotEmpty) {
        paths.add(matched[0]);
      }
    }
    return paths;
  }

  List<ChoreoPath> _getChoreoPathsFromNames(List<String> names) {
    List<ChoreoPath> paths = [];
    for (String name in names) {
      List<ChoreoPath> matched = _choreoPaths.where((path) => path.name == name).toList();
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
            ColorScheme colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
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
        _sortAutos(_autoSortValue);
      });
    }
  }

  void _sortPaths(String sortOption) {
    // Get the latest sort option from shared preferences
    String latestSortOption =
        widget.prefs.getString(PrefsKeys.pathSortOption) ?? Defaults.pathSortOption;

    switch (latestSortOption) {
      case 'recent':
        _paths.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _pathFolders.sort((a, b) => a.compareTo(b));
        break;
      case 'nameDesc':
        _paths.sort((a, b) => b.name.compareTo(a.name));
        _pathFolders.sort((a, b) => b.compareTo(a));
        break;
      case 'nameAsc':
        _paths.sort((a, b) => a.name.compareTo(b.name));
        _pathFolders.sort((a, b) => a.compareTo(b));
        break;
      default:
        throw FormatException('Invalid sort value', sortOption);
    }
  }

  void _sortAutos(String sortOption) {
    switch (sortOption) {
      case 'recent':
        _autos.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _autoFolders.sort((a, b) => a.compareTo(b));
        break;
      case 'nameDesc':
        _autos.sort((a, b) => b.name.compareTo(a.name));
        _autoFolders.sort((a, b) => b.compareTo(a));
        break;
      case 'nameAsc':
        _autos.sort((a, b) => a.name.compareTo(b.name));
        _autoFolders.sort((a, b) => a.compareTo(b));
        break;
      default:
        throw FormatException('Invalid sort value', sortOption);
    }
  }

  List<PopupMenuItem<String>> _sortOptions() {
    return const [
      PopupMenuItem(
        value: 'recent',
        child: Text('Recent'),
      ),
      PopupMenuItem(
        value: 'nameAsc',
        child: Text('Name Ascending'),
      ),
      PopupMenuItem(
        value: 'nameDesc',
        child: Text('Name Descending'),
      ),
    ];
  }

  PathConstraints _getDefaultConstraints() {
    return PathConstraints(
      maxVelocityMPS: widget.prefs.getDouble(PrefsKeys.defaultMaxVel) ?? Defaults.defaultMaxVel,
      maxAccelerationMPSSq:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAccel) ?? Defaults.defaultMaxAccel,
      maxAngularVelocityDeg:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAngVel) ?? Defaults.defaultMaxAngVel,
      maxAngularAccelerationDeg:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAngAccel) ?? Defaults.defaultMaxAngAccel,
      nominalVoltage:
          widget.prefs.getDouble(PrefsKeys.defaultNominalVoltage) ?? Defaults.defaultNominalVoltage,
    );
  }
}
