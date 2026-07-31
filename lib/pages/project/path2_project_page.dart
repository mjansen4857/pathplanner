import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:path/path.dart' as p;
import 'package:pathplanner/pages/path2_auto_editor_page.dart';
import 'package:pathplanner/pages/path2_editor_page.dart';
import 'package:pathplanner/pages/project/project_item_card.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/dialogs/project_conditions_dialog.dart';
import 'package:pathplanner/widgets/dialogs/project_events_dialog.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

/// Live project browser backed only by the Path2 model.
class Path2ProjectPage extends StatefulWidget {
  static bool settingsUpdated = false;

  final SharedPreferences prefs;
  final FieldImage fieldImage;
  final Directory pathplannerDirectory;
  final FileSystem fs;
  final ChangeStack undoStack;
  final bool shortcuts;
  final VoidCallback? onFoldersChanged;

  const Path2ProjectPage({
    super.key,
    required this.prefs,
    required this.fieldImage,
    required this.pathplannerDirectory,
    required this.fs,
    required this.undoStack,
    this.shortcuts = true,
    this.onFoldersChanged,
  });

  @override
  State<Path2ProjectPage> createState() => _Path2ProjectPageState();
}

class _Path2ProjectPageState extends State<Path2ProjectPage> {
  final MultiSplitViewController _splitController = MultiSplitViewController();
  final TextEditingController _pathSearchController = TextEditingController();
  final TextEditingController _autoSearchController = TextEditingController();

  List<path2.Path> _paths = [];
  List<Path2Auto> _autos = [];
  List<String> _pathFolders = [];
  List<String> _autoFolders = [];
  Set<String> _reservedPathNames = {};
  Set<String> _reservedAutoNames = {};

  late Directory _pathsDirectory;
  late Directory _autosDirectory;
  late String _pathSortValue;
  late String _autoSortValue;
  late bool _pathsCompact;
  late bool _autosCompact;
  late int _pathGridCount;
  late int _autoGridCount;

  String _pathSearchQuery = '';
  String _autoSearchQuery = '';
  String? _pathFolder;
  String? _autoFolder;
  bool _loading = true;

  FileSystem get fs => widget.fs;

  @override
  void initState() {
    super.initState();

    final leftWeight = widget.prefs.getDouble(PrefsKeys.projectLeftWeight) ??
        Defaults.projectLeftWeight;
    _splitController.areas = [
      Area(weight: leftWeight, minimalWeight: 0.33),
      Area(weight: 1 - leftWeight, minimalWeight: 0.33),
    ];
    _pathGridCount = _gridCount(leftWeight);
    _autoGridCount = _gridCount(1 - leftWeight);
    _pathSortValue = widget.prefs.getString(PrefsKeys.pathSortOption) ??
        Defaults.pathSortOption;
    _autoSortValue = widget.prefs.getString(PrefsKeys.autoSortOption) ??
        Defaults.autoSortOption;
    _pathsCompact = widget.prefs.getBool(PrefsKeys.pathsCompactView) ??
        Defaults.pathsCompactView;
    _autosCompact = widget.prefs.getBool(PrefsKeys.autosCompactView) ??
        Defaults.autosCompactView;
    _pathFolders = List.of(
      widget.prefs.getStringList(PrefsKeys.pathFolders) ?? Defaults.pathFolders,
    );
    _autoFolders = List.of(
      widget.prefs.getStringList(PrefsKeys.autoFolders) ?? Defaults.autoFolders,
    );

    _load();
  }

  @override
  void dispose() {
    _pathSearchController.dispose();
    _autoSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _pathsDirectory =
        fs.directory(p.join(widget.pathplannerDirectory.path, 'paths'));
    _autosDirectory =
        fs.directory(p.join(widget.pathplannerDirectory.path, 'autos'));
    _pathsDirectory.createSync(recursive: true);
    _autosDirectory.createSync(recursive: true);

    final reservedPaths = _physicalBasenames(_pathsDirectory, '.path');
    final reservedAutos = _physicalBasenames(_autosDirectory, '.auto');
    final paths = await path2.Path.loadAllPathsInDir(_pathsDirectory.path, fs);
    final autos = await Path2Auto.loadAllAutosInDir(
      _autosDirectory.path,
      fs,
      paths: paths,
    );

    for (final path in paths) {
      if (!_pathFolders.contains(path.folder)) {
        path.folder = null;
      }
    }
    for (final auto in autos) {
      if (!_autoFolders.contains(auto.folder)) {
        auto.folder = null;
      }
    }

    ProjectConditionRegistry.rebuild([
      for (final path in paths) ...path.getAllConditionNames(),
      for (final auto in autos) ...auto.getAllConditionNames(),
    ]);

    if (reservedPaths.isEmpty) {
      final example = path2.Path.defaultPath(
        pathDir: _pathsDirectory.path,
        name: 'Example Path',
        fs: fs,
      );
      example.saveFile();
      paths.add(example);
      reservedPaths.add(example.name);
    }

    if (!mounted) return;
    setState(() {
      _paths = paths;
      _autos = autos;
      _reservedPathNames = reservedPaths;
      _reservedAutoNames = reservedAutos;
      _pathFolder = null;
      _autoFolder = null;
      _sortPaths();
      _sortAutos();
      _loading = false;
    });
  }

  Set<String> _physicalBasenames(Directory directory, String extension) {
    return directory
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == extension)
        .map((file) => p.basenameWithoutExtension(file.path))
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Project settings remain available, but Path2 has no global-constraint
    // migration to apply.
    Path2ProjectPage.settingsUpdated = false;

    final colorScheme = Theme.of(context).colorScheme;
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
              controller: _splitController,
              onWeightChange: () {
                final leftWeight = _splitController.areas[0].weight ?? 0.5;
                setState(() {
                  _pathGridCount = _gridCount(leftWeight);
                  _autoGridCount = _gridCount(1 - leftWeight);
                });
                widget.prefs.setDouble(PrefsKeys.projectLeftWeight, leftWeight);
              },
              children: [
                _buildPathsPane(context),
                _buildAutosPane(context),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'manageEvents',
                  tooltip: 'Manage Events',
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  onPressed: _showEventsDialog,
                  child: const Icon(Icons.edit_note_rounded),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'manageConditions',
                  tooltip: 'Manage Conditions',
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  onPressed: _showConditionsDialog,
                  child: const Icon(Icons.question_mark_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPathsPane(BuildContext context) {
    return _buildPane<path2.Path>(
      context: context,
      isPathPane: true,
      compact: _pathsCompact,
      sortValue: _pathSortValue,
      gridCount: _pathGridCount,
      folders: _pathFolders,
      currentFolder: _pathFolder,
      searchController: _pathSearchController,
      searchQuery: _pathSearchQuery,
      items: _paths,
      getName: (path) => path.name,
      getFolder: (path) => path.folder,
      buildCard: (path) => _buildPathCard(path, context),
      moveToFolder: (path, folder) {
        setState(() => path.folder = folder);
        path.saveFile();
      },
      selectFolder: (folder) => setState(() => _pathFolder = folder),
      onSearch: (query) => setState(() => _pathSearchQuery = query),
      onAddItem: _createPath,
      onAddFolder: _createPathFolder,
      onDeleteFolder: _deletePathFolder,
      onRenameFolder: _renamePathFolder,
      onCompactChanged: (compact) {
        widget.prefs.setBool(PrefsKeys.pathsCompactView, compact);
        setState(() => _pathsCompact = compact);
      },
      onSortChanged: (sort) {
        widget.prefs.setString(PrefsKeys.pathSortOption, sort);
        setState(() {
          _pathSortValue = sort;
          _sortPaths();
        });
      },
    );
  }

  Widget _buildAutosPane(BuildContext context) {
    return _buildPane<Path2Auto>(
      context: context,
      isPathPane: false,
      compact: _autosCompact,
      sortValue: _autoSortValue,
      gridCount: _autoGridCount,
      folders: _autoFolders,
      currentFolder: _autoFolder,
      searchController: _autoSearchController,
      searchQuery: _autoSearchQuery,
      items: _autos,
      getName: (auto) => auto.name,
      getFolder: (auto) => auto.folder,
      buildCard: (auto) => _buildAutoCard(auto, context),
      moveToFolder: (auto, folder) {
        setState(() => auto.folder = folder);
        auto.saveFile();
      },
      selectFolder: (folder) => setState(() => _autoFolder = folder),
      onSearch: (query) => setState(() => _autoSearchQuery = query),
      onAddItem: _createAuto,
      onAddFolder: _createAutoFolder,
      onDeleteFolder: _deleteAutoFolder,
      onRenameFolder: _renameAutoFolder,
      onCompactChanged: (compact) {
        widget.prefs.setBool(PrefsKeys.autosCompactView, compact);
        setState(() => _autosCompact = compact);
      },
      onSortChanged: (sort) {
        widget.prefs.setString(PrefsKeys.autoSortOption, sort);
        setState(() {
          _autoSortValue = sort;
          _sortAutos();
        });
      },
    );
  }

  Widget _buildPane<T extends Object>({
    required BuildContext context,
    required bool isPathPane,
    required bool compact,
    required String sortValue,
    required int gridCount,
    required List<String> folders,
    required String? currentFolder,
    required TextEditingController searchController,
    required String searchQuery,
    required List<T> items,
    required String Function(T) getName,
    required String? Function(T) getFolder,
    required Widget Function(T) buildCard,
    required void Function(T, String?) moveToFolder,
    required ValueChanged<String?> selectFolder,
    required ValueChanged<String> onSearch,
    required VoidCallback onAddItem,
    required VoidCallback onAddFolder,
    required VoidCallback onDeleteFolder,
    required void Function(String oldName, String newName) onRenameFolder,
    required ValueChanged<bool> onCompactChanged,
    required ValueChanged<String> onSortChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleItems = items
        .where((item) =>
            getFolder(item) == currentFolder &&
            getName(item).toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: isPathPane ? 8 : 0,
        right: isPathPane ? 0 : 8,
        top: 8,
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildOptionsRow(
                isPathPane: isPathPane,
                compact: compact,
                sortValue: sortValue,
                currentFolder: currentFolder,
                searchController: searchController,
                onSearch: onSearch,
                onAddItem: onAddItem,
                onAddFolder: onAddFolder,
                onDeleteFolder: onDeleteFolder,
                onCompactChanged: onCompactChanged,
                onSortChanged: onSortChanged,
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (currentFolder != null)
                      GridView.count(
                        crossAxisCount: gridCount,
                        childAspectRatio: 5.5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildFolderCard<T>(
                            title: 'Root Folder',
                            root: true,
                            onOpened: () => selectFolder(null),
                            onAccepted: (item) => moveToFolder(item, null),
                          ),
                        ],
                      )
                    else if (folders.isNotEmpty)
                      GridView.count(
                        crossAxisCount: gridCount,
                        childAspectRatio: 5.5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final folder in folders)
                            _buildFolderCard<T>(
                              title: folder,
                              onOpened: () => selectFolder(folder),
                              onAccepted: (item) => moveToFolder(item, folder),
                              onRenamed: (newName) =>
                                  onRenameFolder(folder, newName),
                            ),
                        ],
                      ),
                    if (currentFolder != null || folders.isNotEmpty)
                      const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: compact ? gridCount + 1 : gridCount,
                      childAspectRatio: compact ? 2.5 : 1.55,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final item in visibleItems) buildCard(item)
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

  Widget _buildFolderCard<T extends Object>({
    required String title,
    required VoidCallback onOpened,
    required ValueChanged<T> onAccepted,
    ValueChanged<String>? onRenamed,
    bool root = false,
  }) {
    return DragTarget<T>(
      onAcceptWithDetails: (details) => onAccepted(details.data),
      builder: (context, candidates, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final highlighted = candidates.isNotEmpty;
        return Card(
          elevation: 2,
          color: highlighted ? colorScheme.primary : colorScheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOpened,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    root
                        ? Icons.drive_file_move_rtl_outlined
                        : Icons.folder_outlined,
                    color: highlighted ? colorScheme.onPrimary : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: root
                          ? Text(
                              title,
                              style: TextStyle(
                                fontSize: 20,
                                color:
                                    highlighted ? colorScheme.onPrimary : null,
                              ),
                            )
                          : RenamableTitle(
                              title: title,
                              textStyle: TextStyle(
                                fontSize: 20,
                                color:
                                    highlighted ? colorScheme.onPrimary : null,
                              ),
                              onRename: onRenamed,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionsRow({
    required bool isPathPane,
    required bool compact,
    required String sortValue,
    required String? currentFolder,
    required TextEditingController searchController,
    required ValueChanged<String> onSearch,
    required VoidCallback onAddItem,
    required VoidCallback onAddFolder,
    required VoidCallback onDeleteFolder,
    required ValueChanged<bool> onCompactChanged,
    required ValueChanged<String> onSortChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Row(
            children: [
              PopupMenuButton<bool>(
                initialValue: compact,
                tooltip: 'View options',
                icon: Icon(
                  compact ? Icons.view_list_rounded : Icons.grid_view_rounded,
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('Default')),
                  PopupMenuItem(value: true, child: Text('Compact')),
                ],
                onSelected: onCompactChanged,
              ),
              PopupMenuButton<String>(
                initialValue: sortValue,
                tooltip: 'Sort options',
                icon: const Icon(Icons.sort_rounded),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'recent', child: Text('Recent')),
                  PopupMenuItem(
                    value: 'nameAsc',
                    child: Text('Name Ascending'),
                  ),
                  PopupMenuItem(
                    value: 'nameDesc',
                    child: Text('Name Descending'),
                  ),
                ],
                onSelected: onSortChanged,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search for ${isPathPane ? "Paths..." : "Autos..."}',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (value == searchController.text && mounted) {
                        onSearch(value);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                tooltip: currentFolder == null
                    ? 'Add new folder'
                    : isPathPane
                        ? 'Delete path folder'
                        : 'Delete auto folder',
                onPressed: currentFolder == null ? onAddFolder : onDeleteFolder,
                icon: Icon(
                  currentFolder == null
                      ? Icons.create_new_folder_outlined
                      : Icons.delete_forever_rounded,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: isPathPane ? 'Add new path' : 'Add new auto',
                onPressed: onAddItem,
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPathCard(path2.Path path, BuildContext context) {
    final diagnostics = path.diagnostics;
    final card = ProjectItemCard(
      name: path.name,
      compact: _pathsCompact,
      fieldImage: widget.fieldImage,
      paths: _pathSegments(path),
      startPoints: [
        for (final node in path.rootNodes) node.waypoint.position,
      ],
      endPoints: [
        for (final node in path.leafNodes) node.waypoint.position,
      ],
      warningMessage: _diagnosticMessage(diagnostics),
      onOpened: () => _openPath(path),
      onDuplicated: () {
        final name = _uniqueName('Copy of ${path.name}', _reservedPathNames,
            prefix: 'Copy of ');
        final copy = path.duplicate(name)..saveFile();
        setState(() {
          _paths.add(copy);
          _reservedPathNames.add(name);
          _sortPaths();
        });
      },
      onDeleted: () {
        final deletedName = path.name;
        path.deletePath();
        setState(() {
          _paths.remove(path);
          _reservedPathNames.remove(deletedName);
        });
        _clearPathReferences({deletedName});
        _rebuildConditionRegistry();
      },
      onRenamed: (name) => _renamePath(path, name, context),
    );
    return _draggableCard<path2.Path>(path, card);
  }

  Widget _buildAutoCard(Path2Auto auto, BuildContext context) {
    final diagnostics = auto.getDiagnostics(paths: _paths);

    final card = ProjectItemCard(
      name: auto.name,
      compact: _autosCompact,
      fieldImage: widget.fieldImage,
      paths: [
        for (final node in auto.nodes.whereType<PathAutoNode>())
          if (_pathForAutoNode(node) case final path2.Path path)
            ..._pathSegments(path),
      ],
      startPoints: [
        for (final node in auto.rootNodes.whereType<PathAutoNode>())
          if (_pathForAutoNode(node) case final path2.Path path)
            for (final root in path.rootNodes) root.waypoint.position,
      ],
      endPoints: [
        for (final node in auto.leafNodes.whereType<PathAutoNode>())
          if (_pathForAutoNode(node) case final path2.Path path)
            for (final leaf in path.leafNodes) leaf.waypoint.position,
      ],
      warningMessage: _diagnosticMessage(diagnostics),
      onOpened: () => _openAuto(auto),
      onDuplicated: () {
        final name = _uniqueName('Copy of ${auto.name}', _reservedAutoNames,
            prefix: 'Copy of ');
        final copy = auto.duplicate(name)..saveFile();
        setState(() {
          _autos.add(copy);
          _reservedAutoNames.add(name);
          _sortAutos();
        });
      },
      onDeleted: () {
        auto.delete();
        setState(() {
          _autos.remove(auto);
          _reservedAutoNames.remove(auto.name);
        });
        _rebuildConditionRegistry();
      },
      onRenamed: (name) => _renameAuto(auto, name, context),
    );
    return _draggableCard<Path2Auto>(auto, card);
  }

  Widget _draggableCard<T extends Object>(T data, Widget card) {
    return LayoutBuilder(
      builder: (context, constraints) => Draggable<T>(
        data: data,
        feedback: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Opacity(opacity: 0.8, child: card),
        ),
        childWhenDragging: const SizedBox.shrink(),
        child: card,
      ),
    );
  }

  void _createPath() {
    final name = _uniqueName('New Path', _reservedPathNames);
    final path = path2.Path.defaultPath(
      pathDir: _pathsDirectory.path,
      name: name,
      fs: fs,
      folder: _pathFolder,
    )..saveFile();
    setState(() {
      _paths.add(path);
      _reservedPathNames.add(name);
      _sortPaths();
    });
  }

  void _createAuto() {
    final name = _uniqueName('New Auto', _reservedAutoNames);
    final auto = Path2Auto.defaultAuto(
      autoDir: _autosDirectory.path,
      name: name,
      fs: fs,
      folder: _autoFolder,
    )..saveFile();
    setState(() {
      _autos.add(auto);
      _reservedAutoNames.add(name);
      _sortAutos();
    });
  }

  String _uniqueName(String initial, Set<String> reserved,
      {String prefix = 'New '}) {
    var name = initial;
    while (_isReserved(reserved, name)) {
      name = '$prefix$name';
    }
    return name;
  }

  bool _isReserved(Set<String> reserved, String candidate) {
    final normalizedCandidate = candidate.toLowerCase();
    return reserved.any((name) => name.toLowerCase() == normalizedCandidate);
  }

  Future<void> _openPath(path2.Path path) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Path2EditorPage(
          prefs: widget.prefs,
          path: path,
          fieldImage: widget.fieldImage,
          undoStack: widget.undoStack,
          onRenamed: (name) => _renamePath(path, name, context),
          shortcuts: widget.shortcuts,
          onPathChanged: () {
            _rebuildConditionRegistry();
            setState(() {});
          },
        ),
      ),
    );
    if (mounted) setState(_sortPaths);
    _rebuildConditionRegistry();
  }

  Future<void> _openAuto(Path2Auto auto) async {
    final pathName = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => Path2AutoEditorPage(
          prefs: widget.prefs,
          auto: auto,
          allPaths: _paths,
          allPathNames: _paths.map((path) => path.name).toList(),
          fieldImage: widget.fieldImage,
          undoStack: widget.undoStack,
          onRenamed: (name) => _renameAuto(auto, name, context),
          shortcuts: widget.shortcuts,
          onAutoChanged: () {
            _rebuildConditionRegistry();
            setState(() {});
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(_sortAutos);
    _rebuildConditionRegistry();
    final path = _paths.firstWhereOrNull((path) => path.name == pathName);
    if (path != null) await _openPath(path);
  }

  path2.Path? _pathForAutoNode(PathAutoNode node) {
    return _paths.firstWhereOrNull((path) => path.name == node.pathName);
  }

  List<List<Translation2d>> _pathSegments(path2.Path path) {
    return [
      for (final branch in path.branches)
        if (path.nodeById(branch.sourceId) case final path2.PathNode source)
          if (path.nodeById(branch.targetId) case final path2.PathNode target)
            [source.waypoint.position, target.waypoint.position],
    ];
  }

  void _renamePath(path2.Path path, String newName, BuildContext context) {
    if (newName == path.name) return;
    if (_isReserved(_reservedPathNames, newName)) {
      setState(() {});
      _showNameCollision(context, '$newName.path');
      return;
    }
    final oldName = path.name;
    path.renamePath(newName);
    for (final auto in _autos) {
      auto.updatePathName(oldName, newName);
    }
    setState(() {
      _reservedPathNames
        ..remove(oldName)
        ..add(newName);
      _sortPaths();
    });
  }

  void _renameAuto(Path2Auto auto, String newName, BuildContext context) {
    if (newName == auto.name) return;
    if (_isReserved(_reservedAutoNames, newName)) {
      setState(() {});
      _showNameCollision(context, '$newName.auto');
      return;
    }
    final oldName = auto.name;
    auto.rename(newName);
    setState(() {
      _reservedAutoNames
        ..remove(oldName)
        ..add(newName);
      _sortAutos();
    });
  }

  void _showNameCollision(BuildContext context, String fileName) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          title: const Text('Unable to Rename'),
          content: Text('The file "$fileName" already exists'),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _clearPathReferences(Iterable<String> deletedPathNames) {
    final deleted = deletedPathNames.toSet();
    for (final auto in _autos) {
      var changed = false;
      for (final node in auto.nodes.whereType<PathAutoNode>()) {
        if (node.pathName != null && deleted.contains(node.pathName)) {
          node.pathName = null;
          changed = true;
        }
      }
      if (changed) {
        auto.saveFile();
      }
    }
    setState(() {});
  }

  void _createPathFolder() {
    final name = _uniqueName('New Folder', _pathFolders.toSet());
    setState(() {
      _pathFolders.add(name);
      _sortPaths();
    });
    _saveFolders();
  }

  void _createAutoFolder() {
    final name = _uniqueName('New Folder', _autoFolders.toSet());
    setState(() {
      _autoFolders.add(name);
      _sortAutos();
    });
    _saveFolders();
  }

  void _renamePathFolder(String oldName, String name) {
    if (oldName == name) return;
    if (_pathFolders.contains(name)) {
      _showFolderCollision(name);
      return;
    }
    for (final path in _paths.where((path) => path.folder == oldName)) {
      path.folder = name;
      path.saveFile();
    }
    setState(() {
      _pathFolders[_pathFolders.indexOf(oldName)] = name;
      if (_pathFolder == oldName) _pathFolder = name;
      _sortPaths();
    });
    _saveFolders();
  }

  void _renameAutoFolder(String oldName, String name) {
    if (oldName == name) return;
    if (_autoFolders.contains(name)) {
      _showFolderCollision(name);
      return;
    }
    for (final auto in _autos.where((auto) => auto.folder == oldName)) {
      auto.folder = name;
      auto.saveFile();
    }
    setState(() {
      _autoFolders[_autoFolders.indexOf(oldName)] = name;
      if (_autoFolder == oldName) _autoFolder = name;
      _sortAutos();
    });
    _saveFolders();
  }

  void _showFolderCollision(String name) {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('The folder "$name" already exists')),
    );
  }

  Future<void> _deletePathFolder() async {
    final folder = _pathFolder;
    if (folder == null || !await _confirmDeleteFolder(folder, true)) return;
    final paths = _paths.where((path) => path.folder == folder).toList();
    final deletedNames = {for (final path in paths) path.name};
    for (final path in paths) {
      path.deletePath();
      _reservedPathNames.remove(path.name);
    }
    setState(() {
      _paths.removeWhere((path) => path.folder == folder);
      _pathFolders.remove(folder);
      _pathFolder = null;
    });
    _clearPathReferences(deletedNames);
    _rebuildConditionRegistry();
    _saveFolders();
  }

  Future<void> _deleteAutoFolder() async {
    final folder = _autoFolder;
    if (folder == null || !await _confirmDeleteFolder(folder, false)) return;
    final autos = _autos.where((auto) => auto.folder == folder).toList();
    for (final auto in autos) {
      auto.delete();
      _reservedAutoNames.remove(auto.name);
    }
    setState(() {
      _autos.removeWhere((auto) => auto.folder == folder);
      _autoFolders.remove(folder);
      _autoFolder = null;
    });
    _rebuildConditionRegistry();
    _saveFolders();
  }

  Future<bool> _confirmDeleteFolder(String folder, bool paths) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Folder'),
            content: Text(
              'Are you sure you want to delete the folder "$folder"?\n\n'
              'This will also delete all ${paths ? "paths" : "autos"} '
              'within the folder. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DELETE'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _saveFolders() {
    widget.prefs.setStringList(PrefsKeys.pathFolders, _pathFolders);
    widget.prefs.setStringList(PrefsKeys.autoFolders, _autoFolders);
    widget.onFoldersChanged?.call();
  }

  void _sortPaths() {
    switch (_pathSortValue) {
      case 'recent':
        _paths.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _pathFolders.sort();
        break;
      case 'nameDesc':
        _paths.sort((a, b) => b.name.compareTo(a.name));
        _pathFolders.sort((a, b) => b.compareTo(a));
        break;
      case 'nameAsc':
        _paths.sort((a, b) => a.name.compareTo(b.name));
        _pathFolders.sort();
        break;
      default:
        throw FormatException('Invalid sort value', _pathSortValue);
    }
  }

  void _sortAutos() {
    switch (_autoSortValue) {
      case 'recent':
        _autos.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _autoFolders.sort();
        break;
      case 'nameDesc':
        _autos.sort((a, b) => b.name.compareTo(a.name));
        _autoFolders.sort((a, b) => b.compareTo(a));
        break;
      case 'nameAsc':
        _autos.sort((a, b) => a.name.compareTo(b.name));
        _autoFolders.sort();
        break;
      default:
        throw FormatException('Invalid sort value', _autoSortValue);
    }
  }

  int _gridCount(double weight) {
    if (weight < 0.4) return 1;
    if (weight < 0.6) return 2;
    return 3;
  }

  void _showEventsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => ProjectEventsDialog(
        onEventRenamed: (_, __) => setState(() {}),
        onEventDeleted: (_) => setState(() {}),
      ),
    );
  }

  void _showConditionsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => ProjectConditionsDialog(
        onConditionRenamed: (oldName, newName) {
          _replaceConditionName(oldName, newName);
        },
        onConditionDeleted: (name) {
          _replaceConditionName(name, null);
        },
      ),
    );
  }

  void _replaceConditionName(String oldName, String? newName) {
    for (final path in _paths) {
      var changed = false;
      for (final branch in path.branches) {
        final transition = branch.transition;
        if (transition is ConditionTransition &&
            transition.conditionName == oldName) {
          transition.conditionName = newName;
          changed = true;
        }
      }
      if (changed) {
        path.saveFile();
      }
    }

    for (final auto in _autos) {
      var changed = false;
      for (final branch in auto.branches) {
        final transition = branch.transition;
        if (transition is ConditionTransition &&
            transition.conditionName == oldName) {
          transition.conditionName = newName;
          changed = true;
        }
      }
      if (changed) {
        auto.saveFile();
      }
    }

    _rebuildConditionRegistry();
    setState(() {});
  }

  void _rebuildConditionRegistry() {
    ProjectConditionRegistry.rebuild([
      for (final path in _paths)
        for (final branch in path.branches)
          if (branch.transition is ConditionTransition)
            (branch.transition as ConditionTransition).conditionName,
      for (final auto in _autos)
        for (final branch in auto.branches)
          if (branch.transition is ConditionTransition)
            (branch.transition as ConditionTransition).conditionName,
    ]);
  }

  String? _diagnosticMessage(GraphDiagnostics diagnostics) {
    final messages = [...diagnostics.hardErrors, ...diagnostics.warnings];
    return messages.isEmpty ? null : messages.join('\n');
  }
}
