import 'dart:async';
import 'dart:math';

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
import 'package:pathplanner/widgets/conditional_widget.dart';
import 'package:pathplanner/widgets/dialogs/management_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';
import 'package:watcher/watcher.dart';

class ProjectPage extends StatefulWidget {
  final SharedPreferences prefs;
  final FieldImage fieldImage;
  final Directory deployDirectory;
  final FileSystem fs;
  final ChangeStack undoStack;
  final bool shortcuts;
  final PPLibTelemetry? telemetry;
  final bool hotReload;
  final VoidCallback? onFoldersChanged;
  final bool simulatePath;
  final bool watchChorFile;
  final String? choreoProjPath;

  // Stupid workaround to get when settings are updated
  static bool settingsUpdated = false;

  const ProjectPage({
    super.key,
    required this.prefs,
    required this.fieldImage,
    required this.deployDirectory,
    required this.fs,
    required this.undoStack,
    this.shortcuts = true,
    this.telemetry,
    this.hotReload = false,
    this.onFoldersChanged,
    this.simulatePath = false,
    this.watchChorFile = false,
    this.choreoProjPath,
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
  late String _pathSortValue;
  late String _autoSortValue;
  late bool _pathsCompact;
  late bool _autosCompact;
  late int _pathGridCount;
  late int _autosGridCount;
  FileWatcher? _chorWatcher;
  StreamSubscription<WatchEvent>? _chorWatcherSub;

  bool _loading = true;

  String? _pathFolder;
  String? _autoFolder;
  bool _inChoreoFolder = false;

  final GlobalKey _addAutoKey = GlobalKey();

  FileSystem get fs => widget.fs;

  @override
  void initState() {
    super.initState();

    double leftWeight = widget.prefs.getDouble(PrefsKeys.projectLeftWeight) ??
        Defaults.projectLeftWeight;
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

    _pathSortValue = widget.prefs.getString(PrefsKeys.pathSortOption) ??
        Defaults.pathSortOption;
    _autoSortValue = widget.prefs.getString(PrefsKeys.autoSortOption) ??
        Defaults.autoSortOption;
    _pathsCompact = widget.prefs.getBool(PrefsKeys.pathsCompactView) ??
        Defaults.pathsCompactView;
    _autosCompact = widget.prefs.getBool(PrefsKeys.autosCompactView) ??
        Defaults.autosCompactView;

    _pathGridCount = _getCrossAxisCountForWeight(leftWeight);
    _autosGridCount = _getCrossAxisCountForWeight(1.0 - leftWeight);

    _pathFolders = widget.prefs.getStringList(PrefsKeys.pathFolders) ??
        Defaults.pathFolders;
    _autoFolders = widget.prefs.getStringList(PrefsKeys.autoFolders) ??
        Defaults.autoFolders;

    // Set up choreo project file watcher if a project is linked
    if (widget.choreoProjPath != null && widget.watchChorFile) {
      _chorWatcher = FileWatcher(widget.choreoProjPath!,
          pollingDelay: const Duration(seconds: 1));

      _chorWatcherSub = _chorWatcher!.events.listen((event) {
        if (event.type == ChangeType.MODIFY) {
          _load();
          if (mounted) {
            if (Navigator.of(this.context).canPop()) {
              // We might have a path or auto open, close it
              Navigator.of(this.context).pop();
            }

            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                content: Text('Linked Choreo project was modified')));
          }
        }
      });
    }

    _load();
  }

  @override
  void dispose() {
    _chorWatcherSub?.cancel();

    super.dispose();
  }

  void _load() async {
    // Make sure dirs exist
    _pathsDirectory = fs.directory(join(widget.deployDirectory.path, 'paths'));
    _pathsDirectory.createSync(recursive: true);
    _autosDirectory = fs.directory(join(widget.deployDirectory.path, 'autos'));
    _autosDirectory.createSync(recursive: true);

    var paths =
        await PathPlannerPath.loadAllPathsInDir(_pathsDirectory.path, fs);
    var autos =
        await PathPlannerAuto.loadAllAutosInDir(_autosDirectory.path, fs);
    List<ChoreoPath> choreoPaths = widget.choreoProjPath == null
        ? []
        : await ChoreoPath.loadAllPathsInProj(widget.choreoProjPath!, fs);

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

      autos[i].handleMissingPaths(
          autos[i].choreoAuto ? allChoreoPathNames : allPathNames);
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
          path.globalConstraints = defaultConstraints.clone();
          path.generateAndSavePath();
        }
      }

      ProjectPage.settingsUpdated = false;
    }

    return Stack(
      children: [
        Container(
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
                  _autosGridCount = _getCrossAxisCountForWeight(
                      1.0 - _controller.areas[0].weight!);
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
              tooltip: 'Manage Named Commands & Linked Waypoints',
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              onPressed: () => showDialog(
                context: context,
                builder: (BuildContext context) => ManagementDialog(
                  onCommandRenamed: (String oldName, String newName) {
                    setState(() {
                      for (PathPlannerPath path in _paths) {
                        for (EventMarker m in path.eventMarkers) {
                          _replaceNamedCommand(
                              oldName, newName, m.command.commands);
                        }
                        path.generateAndSavePath();
                      }

                      for (PathPlannerAuto auto in _autos) {
                        _replaceNamedCommand(
                            oldName, newName, auto.sequence.commands);
                        auto.saveFile();
                      }
                    });
                  },
                  onCommandDeleted: (String name) {
                    setState(() {
                      for (PathPlannerPath path in _paths) {
                        for (EventMarker m in path.eventMarkers) {
                          _replaceNamedCommand(name, null, m.command.commands);
                        }
                        path.generateAndSavePath();
                      }

                      for (PathPlannerAuto auto in _autos) {
                        _replaceNamedCommand(
                            name, null, auto.sequence.commands);
                        auto.saveFile();
                      }
                    });
                  },
                  onLinkedRenamed: (String oldName, String newName) {
                    setState(() {
                      Point? pos = Waypoint.linked.remove(oldName);

                      if (pos != null) {
                        Waypoint.linked[newName] = pos;

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
                    color: colorScheme.surfaceTint.withOpacity(0.1),
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

  void _replaceNamedCommand(
      String originalName, String? newName, List<Command> commands) {
    for (Command cmd in commands) {
      if (cmd is NamedCommand && cmd.name == originalName) {
        cmd.name = newName;
      } else if (cmd is CommandGroup) {
        _replaceNamedCommand(originalName, newName, cmd.commands);
      }
    }
  }

  Widget _buildPathsGrid(BuildContext context) {
    if (_inChoreoFolder) {
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
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        'Choreo Paths',
                        style: TextStyle(fontSize: 32),
                      ),
                    ),
                    Expanded(child: Container()),
                  ],
                ),
                const Divider(),
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
                    crossAxisCount:
                        _pathsCompact ? _pathGridCount + 1 : _pathGridCount,
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
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      _pathFolder ?? 'Paths',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  Expanded(child: Container()),
                  ConditionalWidget(
                    condition: _pathFolder == null,
                    falseChild: Tooltip(
                      message: 'Delete path folder',
                      waitDuration: const Duration(seconds: 1),
                      child: IconButton.filledTonal(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Delete Folder'),
                                  content: SizedBox(
                                    width: 400,
                                    child: Text(
                                        'Are you sure you want to delete the folder "$_pathFolder"?\n\nThis will also delete all paths within the folder. This cannot be undone.'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: Navigator.of(context).pop,
                                      child: const Text('CANCEL'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();

                                        for (int p = 0;
                                            p < _paths.length;
                                            p++) {
                                          if (_paths[p].folder == _pathFolder) {
                                            _paths[p].deletePath();
                                          }
                                        }

                                        setState(() {
                                          _paths.removeWhere((path) =>
                                              path.folder == _pathFolder);
                                          _pathFolders.remove(_pathFolder);
                                          _pathFolder = null;
                                        });
                                        widget.prefs.setStringList(
                                            PrefsKeys.pathFolders,
                                            _pathFolders);
                                        widget.onFoldersChanged?.call();
                                      },
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                );
                              });
                        },
                        icon: const Icon(Icons.delete_forever),
                      ),
                    ),
                    trueChild: Tooltip(
                      message: 'Add new path folder',
                      waitDuration: const Duration(seconds: 1),
                      child: IconButton.filledTonal(
                        onPressed: () {
                          String folderName = 'New Folder';
                          while (_pathFolders.contains(folderName)) {
                            folderName = 'New $folderName';
                          }

                          setState(() {
                            _pathFolders.add(folderName);
                            _sortPaths(_pathSortValue);
                          });
                          widget.prefs.setStringList(
                              PrefsKeys.pathFolders, _pathFolders);
                          widget.onFoldersChanged?.call();
                        },
                        icon: const Icon(Icons.create_new_folder_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Add new path',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton.filled(
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
                            fs: fs,
                            folder: _pathFolder,
                            constraints: _getDefaultConstraints(),
                          ));
                          _sortPaths(_pathSortValue);
                        });
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              const Divider(),
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
              ),
              ConditionalWidget(
                condition: _pathFolder == null,
                falseChild: GridView.count(
                  crossAxisCount: _pathGridCount,
                  childAspectRatio: 5.5,
                  shrinkWrap: true,
                  children: [
                    DragTarget<PathPlannerPath>(
                      onAccept: (data) {
                        setState(() {
                          data.folder = null;
                          data.generateAndSavePath();
                        });
                      },
                      builder: (context, candidates, rejects) {
                        ColorScheme colorScheme = Theme.of(context).colorScheme;
                        return Card(
                          elevation: 2,
                          color: candidates.isNotEmpty
                              ? colorScheme.primary
                              : null,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _pathFolder = null;
                              });
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drive_file_move_rtl_outlined,
                                    color: candidates.isNotEmpty
                                        ? colorScheme.onPrimary
                                        : null,
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
                  children: [
                    if (_choreoPaths.isNotEmpty)
                      Card(
                        elevation: 2,
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
                        onAccept: (data) {
                          setState(() {
                            data.folder = _pathFolders[i];
                            data.generateAndSavePath();
                          });
                        },
                        builder: (context, candidates, rejects) {
                          ColorScheme colorScheme =
                              Theme.of(context).colorScheme;
                          return Card(
                            elevation: 2,
                            color: candidates.isNotEmpty
                                ? colorScheme.primary
                                : null,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _pathFolder = _pathFolders[i];
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
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
                                              if (_pathFolders
                                                  .contains(newName)) {
                                                showDialog(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                            'Unable to Rename'),
                                                        content: Text(
                                                            'The folder "$newName" already exists'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                Navigator.of(
                                                                        context)
                                                                    .pop,
                                                            child: const Text(
                                                                'OK'),
                                                          ),
                                                        ],
                                                      );
                                                    });
                                              } else {
                                                setState(() {
                                                  for (PathPlannerPath path
                                                      in _paths) {
                                                    if (path.folder ==
                                                        _pathFolders[i]) {
                                                      path.folder = newName;
                                                      path.generateAndSavePath();
                                                    }
                                                  }
                                                  _pathFolders[i] = newName;
                                                });
                                                widget.prefs.setStringList(
                                                    PrefsKeys.pathFolders,
                                                    _pathFolders);
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
              Expanded(
                child: GridView.count(
                  crossAxisCount:
                      _pathsCompact ? _pathGridCount + 1 : _pathGridCount,
                  childAspectRatio: _pathsCompact ? 2.5 : 1.55,
                  children: [
                    for (int i = 0; i < _paths.length; i++)
                      if (_paths[i].folder == _pathFolder)
                        _buildPathCard(i, context),
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
      paths: [_paths[i].getPathPositions()],
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
      onRenamed: (value) => _renamePath(i, value, context),
      onOpened: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PathEditorPage(
              prefs: widget.prefs,
              path: _paths[i],
              fieldImage: widget.fieldImage,
              undoStack: widget.undoStack,
              onRenamed: (value) => _renamePath(i, value, context),
              shortcuts: widget.shortcuts,
              telemetry: widget.telemetry,
              hotReload: widget.hotReload,
              simulatePath: widget.simulatePath,
              onPathChanged: () {
                // Make sure all paths with linked waypoints are updated
                for (PathPlannerPath p in _paths) {
                  bool changed = false;

                  for (Waypoint w in p.waypoints) {
                    if (w.linkedName != null) {
                      var anchor = Waypoint.linked[w.linkedName];

                      if (anchor != null &&
                          anchor.distanceTo(w.anchor) >= 0.01) {
                        w.move(anchor.x, anchor.y);
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
      },
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
      paths: [_choreoPaths[i].getPathPositions()],
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
      String oldName = _paths[pathIdx].name;
      setState(() {
        _paths[pathIdx].renamePath(newName);
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
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      _autoFolder ?? 'Autos',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  Expanded(child: Container()),
                  ConditionalWidget(
                    condition: _autoFolder == null,
                    falseChild: Tooltip(
                      message: 'Delete auto folder',
                      waitDuration: const Duration(seconds: 1),
                      child: IconButton.filledTonal(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Delete Folder'),
                                  content: SizedBox(
                                    width: 400,
                                    child: Text(
                                        'Are you sure you want to delete the folder "$_autoFolder"?\n\nThis will also delete all autos within the folder. This cannot be undone.'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: Navigator.of(context).pop,
                                      child: const Text('CANCEL'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();

                                        for (int a = 0;
                                            a < _autos.length;
                                            a++) {
                                          if (_autos[a].folder == _autoFolder) {
                                            _autos[a].delete();
                                          }
                                        }

                                        setState(() {
                                          _autos.removeWhere((auto) =>
                                              auto.folder == _autoFolder);
                                          _autoFolders.remove(_autoFolder);
                                          _autoFolder = null;
                                        });
                                        widget.prefs.setStringList(
                                            PrefsKeys.autoFolders,
                                            _autoFolders);
                                        widget.onFoldersChanged?.call();
                                      },
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                );
                              });
                        },
                        icon: const Icon(Icons.delete_forever),
                      ),
                    ),
                    trueChild: Tooltip(
                      message: 'Add new auto folder',
                      waitDuration: const Duration(seconds: 1),
                      child: IconButton.filledTonal(
                        onPressed: () {
                          String folderName = 'New Folder';
                          while (_autoFolders.contains(folderName)) {
                            folderName = 'New $folderName';
                          }

                          setState(() {
                            _autoFolders.add(folderName);
                            _sortAutos(_autoSortValue);
                          });
                          widget.prefs.setStringList(
                              PrefsKeys.autoFolders, _autoFolders);
                          widget.onFoldersChanged?.call();
                        },
                        icon: const Icon(Icons.create_new_folder_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Add new auto',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton.filled(
                      key: _addAutoKey,
                      onPressed: () {
                        if (_choreoPaths.isNotEmpty) {
                          final RenderBox renderBox = _addAutoKey.currentContext
                              ?.findRenderObject() as RenderBox;
                          final Size size = renderBox.size;
                          final Offset offset =
                              renderBox.localToGlobal(Offset.zero);

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
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              const Divider(),
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
              ),
              ConditionalWidget(
                condition: _autoFolder == null,
                falseChild: GridView.count(
                  crossAxisCount: _autosGridCount,
                  childAspectRatio: 5.5,
                  shrinkWrap: true,
                  children: [
                    DragTarget<PathPlannerAuto>(
                      onAccept: (data) {
                        setState(() {
                          data.folder = null;
                          data.saveFile();
                        });
                      },
                      builder: (context, candidates, rejects) {
                        ColorScheme colorScheme = Theme.of(context).colorScheme;
                        return Card(
                          elevation: 2,
                          color: candidates.isNotEmpty
                              ? colorScheme.primary
                              : null,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _autoFolder = null;
                              });
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drive_file_move_rtl_outlined,
                                    color: candidates.isNotEmpty
                                        ? colorScheme.onPrimary
                                        : null,
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
                  children: [
                    for (int i = 0; i < _autoFolders.length; i++)
                      DragTarget<PathPlannerAuto>(
                        onAccept: (data) {
                          setState(() {
                            data.folder = _autoFolders[i];
                            data.saveFile();
                          });
                        },
                        builder: (context, candidates, rejects) {
                          ColorScheme colorScheme =
                              Theme.of(context).colorScheme;
                          return Card(
                            elevation: 2,
                            color: candidates.isNotEmpty
                                ? colorScheme.primary
                                : null,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _autoFolder = _autoFolders[i];
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
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
                                              if (_autoFolders
                                                  .contains(newName)) {
                                                showDialog(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                            'Unable to Rename'),
                                                        content: Text(
                                                            'The folder "$newName" already exists'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                Navigator.of(
                                                                        context)
                                                                    .pop,
                                                            child: const Text(
                                                                'OK'),
                                                          ),
                                                        ],
                                                      );
                                                    });
                                              } else {
                                                setState(() {
                                                  for (PathPlannerAuto auto
                                                      in _autos) {
                                                    if (auto.folder ==
                                                        _autoFolders[i]) {
                                                      auto.folder = newName;
                                                      auto.saveFile();
                                                    }
                                                  }
                                                  _autoFolders[i] = newName;
                                                });
                                                widget.prefs.setStringList(
                                                    PrefsKeys.autoFolders,
                                                    _autoFolders);
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
              Expanded(
                child: GridView.count(
                  crossAxisCount:
                      _autosCompact ? _autosGridCount + 1 : _autosGridCount,
                  childAspectRatio: _autosCompact ? 2.5 : 1.55,
                  children: [
                    for (int i = 0; i < _autos.length; i++)
                      if (_autos[i].folder == _autoFolder)
                        _buildAutoCard(i, context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildAutoCard(int i, BuildContext context) {
    String? warningMessage;

    if (_autos[i].hasEmptyPathCommands()) {
      warningMessage =
          'Contains a FollowPathCommand that does not have a path selected';
    } else if (_autos[i].hasEmptyNamedCommand()) {
      warningMessage =
          'Contains a NamedCommand that does not have a command selected';
    }

    final autoCard = ProjectItemCard(
      name: _autos[i].name,
      compact: _autosCompact,
      fieldImage: widget.fieldImage,
      choreoItem: _autos[i].choreoAuto,
      paths: _autos[i].choreoAuto
          ? [
              for (ChoreoPath path
                  in _getChoreoPathsFromNames(_autos[i].getAllPathNames()))
                path.getPathPositions(),
            ]
          : [
              for (PathPlannerPath path
                  in _getPathsFromNames(_autos[i].getAllPathNames()))
                path.getPathPositions(),
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
      onDeleted: () {
        _autos[i].delete();
        setState(() {
          _autos.removeAt(i);
        });
      },
      onRenamed: (value) => _renameAuto(i, value, context),
      onOpened: () async {
        await Navigator.push(
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Sort:',
                style: TextStyle(fontSize: 16),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<String>(
                    initialValue: sortValue,
                    tooltip: '',
                    elevation: 12.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: onSortChanged,
                    itemBuilder: (context) => _sortOptions(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _sortLabel(sortValue),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'View:',
                style: TextStyle(fontSize: 16),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.transparent,
                  child: PopupMenuButton<bool>(
                    initialValue: viewValue,
                    tooltip: '',
                    elevation: 12.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: onViewChanged,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: false,
                        child: Text('Default'),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: Text('Compact'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(viewValue ? 'Compact' : 'Default',
                              style: const TextStyle(fontSize: 16)),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  List<ChoreoPath> _getChoreoPathsFromNames(List<String> names) {
    List<ChoreoPath> paths = [];
    for (String name in names) {
      List<ChoreoPath> matched =
          _choreoPaths.where((path) => path.name == name).toList();
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
        _sortAutos(_autoSortValue);
      });
    }
  }

  void _sortPaths(String sortOption) {
    switch (sortOption) {
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

  Widget _sortLabel(String optionValue) {
    return switch (optionValue) {
      'recent' => const Text('Recent', style: TextStyle(fontSize: 16)),
      'nameDesc' =>
        const Text('Name Descending', style: TextStyle(fontSize: 16)),
      'nameAsc' => const Text('Name Ascending', style: TextStyle(fontSize: 16)),
      _ => throw FormatException('Invalid sort value', optionValue),
    };
  }

  PathConstraints _getDefaultConstraints() {
    return PathConstraints(
      maxVelocity: widget.prefs.getDouble(PrefsKeys.defaultMaxVel) ??
          Defaults.defaultMaxVel,
      maxAcceleration: widget.prefs.getDouble(PrefsKeys.defaultMaxAccel) ??
          Defaults.defaultMaxAccel,
      maxAngularVelocity: widget.prefs.getDouble(PrefsKeys.defaultMaxAngVel) ??
          Defaults.defaultMaxAngVel,
      maxAngularAcceleration:
          widget.prefs.getDouble(PrefsKeys.defaultMaxAngAccel) ??
              Defaults.defaultMaxAngAccel,
    );
  }
}
