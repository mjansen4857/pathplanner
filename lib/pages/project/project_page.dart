import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:path/path.dart';
import 'package:pathplanner/pages/auto_editor_page.dart';
import 'package:pathplanner/pages/path_editor_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/pplib_telemetry.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class ProjectPage extends StatefulWidget {
  final SharedPreferences prefs;
  final FieldImage fieldImage;
  final Directory deployDirectory;
  final FileSystem fs;
  final ChangeStack undoStack;
  final bool shortcuts;
  final PPLibTelemetry? telemetry;
  final bool hotReload;

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
  late Directory _pathsDirectory;
  late Directory _autosDirectory;
  late String _pathSortValue;
  late String _autoSortValue;
  late bool _pathsCompact;
  late bool _autosCompact;
  late int _pathGridCount;
  late int _autosGridCount;

  bool _loading = true;

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

    _load();
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

    setState(() {
      _paths = paths;
      _autos = autos;

      if (_paths.isEmpty) {
        _paths.add(PathPlannerPath.defaultPath(
          pathDir: _pathsDirectory.path,
          name: 'Example Path',
          fs: fs,
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
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Text(
                      'Paths',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                  Expanded(child: Container()),
                  Tooltip(
                    message: 'Add new folder',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton.filledTonal(
                      onPressed: () {
                        String folderName = 'New Folder';
                        while (_pathFolders.contains(folderName)) {
                          folderName = 'New $folderName';
                        }

                        setState(() {
                          _pathFolders.add(folderName);
                        });
                        widget.prefs
                            .setStringList(PrefsKeys.pathFolders, _pathFolders);
                      },
                      icon: const Icon(Icons.create_new_folder_outlined),
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
                          ));
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
                  for (int i = 0; i < _pathFolders.length; i++)
                    DragTarget<PathPlannerPath>(
                      onAccept: (data) {
                        // TODO move into folder
                        print('${data.name} placed in ${_pathFolders[i]}');
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
                              // TODO: open folder
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
                                                          child:
                                                              const Text('OK'),
                                                        ),
                                                      ],
                                                    );
                                                  });
                                            } else {
                                              setState(() {
                                                _pathFolders[i] = newName;
                                              });
                                              widget.prefs.setStringList(
                                                  PrefsKeys.pathFolders,
                                                  _pathFolders);
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
              if (_pathFolders.isNotEmpty) const SizedBox(height: 8),
              Expanded(
                child: GridView.count(
                  crossAxisCount:
                      _pathsCompact ? _pathGridCount + 1 : _pathGridCount,
                  childAspectRatio: _pathsCompact ? 2.5 : 1.55,
                  children: [
                    for (int i = 0; i < _paths.length; i++)
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
            ),
          ),
        );

        // Wait for the user to go back then rebuild so the path preview updates (most of the time...)
        setState(() {});
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
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Text(
                      'Autos',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                  Expanded(child: Container()),
                  Tooltip(
                    message: 'Add new folder',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton.filledTonal(
                      onPressed: () {
                        String folderName = 'New Folder';
                        while (_autoFolders.contains(folderName)) {
                          folderName = 'New $folderName';
                        }

                        setState(() {
                          _autoFolders.add(folderName);
                        });
                        widget.prefs
                            .setStringList(PrefsKeys.autoFolders, _autoFolders);
                      },
                      icon: const Icon(Icons.create_new_folder_outlined),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Add new auto',
                    waitDuration: const Duration(seconds: 1),
                    child: IconButton.filled(
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
                            fs: fs,
                          ));
                        });
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
                  setState(() {
                    _autosCompact = value;
                  });
                },
              ),
              GridView.count(
                crossAxisCount: _autosGridCount,
                childAspectRatio: 5.5,
                shrinkWrap: true,
                children: [
                  for (int i = 0; i < _autoFolders.length; i++)
                    Card(
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_outlined),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: RenamableTitle(
                                    title: _autoFolders[i],
                                    textStyle: const TextStyle(fontSize: 20),
                                    onRename: (newName) {
                                      if (newName != _autoFolders[i]) {
                                        if (_autoFolders.contains(newName)) {
                                          showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text(
                                                      'Unable to Rename'),
                                                  content: Text(
                                                      'The folder "$newName" already exists'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          Navigator.of(context)
                                                              .pop,
                                                      child: const Text('OK'),
                                                    ),
                                                  ],
                                                );
                                              });
                                        } else {
                                          setState(() {
                                            _autoFolders[i] = newName;
                                          });
                                          widget.prefs.setStringList(
                                              PrefsKeys.autoFolders,
                                              _autoFolders);
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
                    ),
                ],
              ),
              if (_autoFolders.isNotEmpty) const SizedBox(height: 8),
              Expanded(
                child: GridView.count(
                  crossAxisCount:
                      _autosCompact ? _autosGridCount + 1 : _autosGridCount,
                  childAspectRatio: _autosCompact ? 2.5 : 1.55,
                  children: [
                    for (int i = 0; i < _autos.length; i++)
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

  Widget _buildAutoCard(int i, BuildContext context) {
    final autoCard = ProjectItemCard(
      name: _autos[i].name,
      compact: _autosCompact,
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
      onRenamed: (value) => _renameAuto(i, value, context),
      onOpened: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AutoEditorPage(
              prefs: widget.prefs,
              auto: _autos[i],
              allPaths: _paths,
              undoStack: widget.undoStack,
              allPathNames: _paths.map((e) => e.name).toList(),
              fieldImage: widget.fieldImage,
              onRenamed: (value) => _renameAuto(i, value, context),
              shortcuts: widget.shortcuts,
              telemetry: widget.telemetry,
              hotReload: widget.hotReload,
            ),
          ),
        );

        // Wait for the user to go back then rebuild so the path preview updates (most of the time...)
        setState(() {});
      },
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

  void _sortPaths(String sortOption) {
    switch (sortOption) {
      case 'nameDesc':
        _paths.sort((a, b) => b.name.compareTo(a.name));
        _pathFolders.sort((a, b) => b.compareTo(a));
      case 'nameAsc':
      default:
        _paths.sort((a, b) => a.name.compareTo(b.name));
        _pathFolders.sort((a, b) => a.compareTo(b));
    }
  }

  void _sortAutos(String sortOption) {
    switch (sortOption) {
      case 'nameDesc':
        _autos.sort((a, b) => b.name.compareTo(a.name));
        _autoFolders.sort((a, b) => b.compareTo(a));
      case 'nameAsc':
      default:
        _autos.sort((a, b) => a.name.compareTo(b.name));
        _autoFolders.sort((a, b) => a.compareTo(b));
    }
  }

  List<PopupMenuItem<String>> _sortOptions() {
    return const [
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
    switch (optionValue) {
      case 'nameDesc':
        return const Text('Name Descending', style: TextStyle(fontSize: 16));
      case 'nameAsc':
      default:
        return const Text('Name Ascending', style: TextStyle(fontSize: 16));
    }
  }
}
