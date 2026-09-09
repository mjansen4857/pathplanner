import 'dart:convert';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:path/path.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/services/project_event_registry.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:version/version.dart';

const String fileVersion = '2027.1';

sealed class AutoNode implements GraphNodeData {
  @override
  final String id;
  @override
  Offset editorPosition;

  List<String> events;

  AutoNode({
    String? id,
    required this.editorPosition,
    List<String> events = const [],
  }) : id = id ?? generateGraphId(),
       events = List.of(events) {
    _validateEvents(events);
    _validateId(this.id, 'Auto node ID');
    validateFiniteOffset(editorPosition, 'editorPosition');
  }

  String get type;

  AutoNode clone();

  Map<String, dynamic> toJson();

  static AutoNode fromJson(Object? value) {
    final json = _jsonObject(value, 'Auto node');
    final type = json['type'];
    if (type is! String) {
      throw const FormatException('Auto node type must be a string');
    }
    return switch (type) {
      'path' => PathAutoNode.fromJson(json),
      'external' => ExternalCommandAutoNode.fromJson(json),
      _ => throw FormatException('Unknown auto node type: $type'),
    };
  }
}

final class PathAutoNode extends AutoNode {
  String? pathName;

  PathAutoNode({
    super.id,
    this.pathName,
    required super.editorPosition,
    super.events,
  });

  factory PathAutoNode.fromJson(Map<String, dynamic> json) {
    final pathName = json['pathName'];
    if (pathName != null && pathName is! String) {
      throw const FormatException('pathName must be a string or null');
    }
    return PathAutoNode(
      id: _requiredId(json, 'id', 'Auto node ID'),
      pathName: pathName as String?,
      events: _eventsFromJson(json['events']),
      editorPosition: editorPositionFromJson(json['editorPosition']),
    );
  }

  @override
  String get type => 'path';

  @override
  PathAutoNode clone() => PathAutoNode(
    id: id,
    pathName: pathName,
    editorPosition: editorPosition,
    events: events,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'pathName': pathName,
    'events': List<String>.of(events),
    'editorPosition': editorPositionToJson(editorPosition),
  };

  @override
  bool operator ==(Object other) =>
      other is PathAutoNode &&
      other.id == id &&
      other.pathName == pathName &&
      other.editorPosition == editorPosition &&
      const ListEquality<String>().equals(other.events, events);

  @override
  int get hashCode => Object.hash(
    id,
    pathName,
    editorPosition,
    const ListEquality<String>().hash(events),
  );
}

final class ExternalCommandAutoNode extends AutoNode {
  String commandName;

  ExternalCommandAutoNode({
    super.id,
    this.commandName = '',
    required super.editorPosition,
    super.events,
  });

  factory ExternalCommandAutoNode.fromJson(Map<String, dynamic> json) {
    final commandName = json['commandName'];
    if (commandName is! String) {
      throw const FormatException('commandName must be a string');
    }
    return ExternalCommandAutoNode(
      id: _requiredId(json, 'id', 'Auto node ID'),
      commandName: commandName,
      events: _eventsFromJson(json['events']),
      editorPosition: editorPositionFromJson(json['editorPosition']),
    );
  }

  @override
  String get type => 'external';

  @override
  ExternalCommandAutoNode clone() => ExternalCommandAutoNode(
    id: id,
    commandName: commandName,
    editorPosition: editorPosition,
    events: events,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'commandName': commandName,
    'events': List<String>.of(events),
    'editorPosition': editorPositionToJson(editorPosition),
  };

  @override
  bool operator ==(Object other) =>
      other is ExternalCommandAutoNode &&
      other.id == id &&
      other.commandName == commandName &&
      other.editorPosition == editorPosition &&
      const ListEquality<String>().equals(other.events, events);

  @override
  int get hashCode => Object.hash(
    id,
    commandName,
    editorPosition,
    const ListEquality<String>().hash(events),
  );
}

class AutoBranch implements GraphBranchData {
  @override
  final String id;
  @override
  final String sourceId;
  @override
  final String targetId;
  AutoTransition transition;
  List<String> events;

  AutoBranch({
    String? id,
    required this.sourceId,
    required this.targetId,
    AutoTransition? transition,
    List<String> events = const [],
  }) : id = id ?? generateGraphId(),
       events = List.of(events),
       transition = transition ?? ConditionTransition() {
    _validateEvents(events);
    _validateId(this.id, 'Auto branch ID');
    _validateId(sourceId, 'Auto branch source ID');
    _validateId(targetId, 'Auto branch target ID');
  }

  factory AutoBranch.fromJson(Object? value) {
    final json = _jsonObject(value, 'Auto branch');
    return AutoBranch(
      id: _requiredId(json, 'id', 'Auto branch ID'),
      sourceId: _requiredId(json, 'sourceId', 'Auto branch source ID'),
      targetId: _requiredId(json, 'targetId', 'Auto branch target ID'),
      transition: AutoTransition.fromJson(json['transition']),
      events: _eventsFromJson(json['events']),
    );
  }

  AutoBranch clone() => AutoBranch(
    id: id,
    sourceId: sourceId,
    targetId: targetId,
    transition: transition.clone(),
    events: events,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'targetId': targetId,
    'transition': transition.toJson(),
    'events': List<String>.of(events),
  };

  @override
  bool operator ==(Object other) =>
      other is AutoBranch &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.targetId == targetId &&
      other.transition == transition &&
      const ListEquality<String>().equals(other.events, events);

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    targetId,
    transition,
    const ListEquality<String>().hash(events),
  );
}

class AutoGraphSnapshot {
  final List<AutoNode> nodes;
  final List<AutoBranch> branches;
  final Pose2d startingPose;
  final bool startingPoseInitialized;

  AutoGraphSnapshot({
    required Iterable<AutoNode> nodes,
    required Iterable<AutoBranch> branches,
    required this.startingPose,
    required this.startingPoseInitialized,
  }) : nodes = [for (final node in nodes) node.clone()],
       branches = [for (final branch in branches) branch.clone()];
}

class Path2Auto {
  static final Version _minimumFileVersion = Version.parse(fileVersion);
  static const Pose2d _zeroPose = Pose2d(Translation2d(), Rotation2d());

  String name;
  List<AutoNode> nodes;
  List<AutoBranch> branches;
  Pose2d startingPose;
  bool startingPoseInitialized;
  String? folder;

  /// The accepted compatible version read from disk.
  String sourceVersion;

  FileSystem fs;
  String autoDir;
  DateTime lastModified = DateTime.now().toUtc();

  Path2Auto({
    required this.name,
    required this.nodes,
    List<AutoBranch>? branches,
    required this.autoDir,
    required this.fs,
    this.startingPose = _zeroPose,
    this.startingPoseInitialized = false,
    this.folder,
    this.sourceVersion = fileVersion,
  }) : branches = branches ?? [] {
    _validatedSourceVersion(sourceVersion);
    _validatePose(startingPose);
    final graphDiagnostics = diagnostics;
    if (graphDiagnostics.hasHardErrors) {
      throw ArgumentError(graphDiagnostics.hardErrors.join('; '));
    }
    _collectConditionNames();
    registerEvents();
  }

  Path2Auto.defaultAuto({
    this.name = 'New Auto',
    required this.autoDir,
    required this.fs,
    this.folder,
  }) : nodes = [],
       branches = [],
       startingPose = _zeroPose,
       startingPoseInitialized = false,
       sourceVersion = fileVersion;

  factory Path2Auto.fromJson(
    Map<String, dynamic> json,
    String name,
    String autosDir,
    FileSystem fs, {
    Iterable<path2.Path> paths = const [],
  }) {
    final sourceVersion = _validatedSourceVersion(json['version']);
    final folder = json['folder'];
    if (folder != null && folder is! String) {
      throw const FormatException('Auto folder must be a string or null');
    }
    final initialized = json['startingPoseInitialized'];
    if (initialized is! bool) {
      throw const FormatException('startingPoseInitialized must be a boolean');
    }

    try {
      return Path2Auto(
        name: name,
        nodes: _nodesFromJson(json['nodes']),
        branches: _branchesFromJson(json['branches']),
        startingPose: _poseFromJson(json['startingPose']),
        startingPoseInitialized: initialized,
        folder: folder as String?,
        sourceVersion: sourceVersion,
        autoDir: autosDir,
        fs: fs,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid auto graph: ${error.message}');
    }
  }

  void registerEvents() {
    for (final node in nodes) {
      ProjectEventRegistry.events.addAll(node.events);
    }
    for (final branch in branches) {
      ProjectEventRegistry.events.addAll(branch.events);
    }
  }

  bool replaceEventName(String oldName, String? newName) {
    var changed = false;
    List<String> replace(List<String> events) {
      if (!events.contains(oldName)) return events;
      changed = true;
      return [
        for (final name in events)
          if (name != oldName) name else ?newName,
      ];
    }

    for (final node in nodes) {
      node.events = replace(node.events);
    }
    for (final branch in branches) {
      branch.events = replace(branch.events);
    }
    if (changed) registerEvents();
    return changed;
  }

  String get version => sourceVersion;

  AutoNode? nodeById(String id) =>
      nodes.firstWhereOrNull((node) => node.id == id);

  List<AutoNode> get rootNodes =>
      GraphAlgorithms.roots<AutoNode, AutoBranch>(nodes, branches);

  List<AutoNode> get leafNodes =>
      GraphAlgorithms.leaves<AutoNode, AutoBranch>(nodes, branches);

  Set<String> reverseReachableNodeIds(String nodeId) {
    if (nodeById(nodeId) == null) {
      return {};
    }
    return GraphAlgorithms.reverseReachableNodeIds<AutoBranch>(
      nodeId,
      branches,
    );
  }

  Set<String> get reachableNodeIds {
    final roots = rootNodes;
    if (roots.length != 1) {
      return {};
    }
    return GraphAlgorithms.reachableNodeIds<AutoBranch>(
      roots.single.id,
      branches,
    );
  }

  GraphDiagnostics get diagnostics => getDiagnostics();

  GraphDiagnostics getDiagnostics({Iterable<path2.Path>? paths}) {
    final hardErrors = _hardGraphErrors(nodes, branches);
    final draftWarnings = <String>[];
    final configurationWarnings = <String>[];

    if (nodes.isNotEmpty && hardErrors.isEmpty) {
      final roots = GraphAlgorithms.roots<AutoNode, AutoBranch>(
        nodes,
        branches,
      );
      if (roots.length != 1) {
        draftWarnings.add(
          'Auto must have exactly one start node; found ${roots.length}',
        );
      } else {
        final reachable = GraphAlgorithms.reachableNodeIds<AutoBranch>(
          roots.single.id,
          branches,
        );
        if (reachable.length != nodes.length) {
          draftWarnings.add('Some auto nodes are unreachable from the start');
        }
      }
    }

    final availablePathNames = paths == null
        ? null
        : {for (final path in paths) path.name};
    for (final node in nodes.whereType<PathAutoNode>()) {
      final pathName = node.pathName;
      if (pathName == null || pathName.trim().isEmpty) {
        configurationWarnings.add('Auto node ${node.id} has no path selected');
      } else if (availablePathNames != null &&
          !availablePathNames.contains(pathName)) {
        configurationWarnings.add(
          'Auto node ${node.id} references missing path "$pathName"',
        );
      }
    }
    for (final node in nodes.whereType<ExternalCommandAutoNode>()) {
      if (node.commandName.trim().isEmpty) {
        configurationWarnings.add('External Command node has no command name');
      }
    }
    for (final branch in branches) {
      final transition = branch.transition;
      if (transition is ConditionTransition &&
          (transition.conditionName == null ||
              transition.conditionName!.trim().isEmpty)) {
        configurationWarnings.add(
          'Branch ${branch.id} has no condition selected',
        );
      }
    }

    return GraphDiagnostics(
      hardErrors: hardErrors,
      draftWarnings: draftWarnings,
      configurationWarnings: configurationWarnings,
    );
  }

  bool canAddBranch(
    String sourceId,
    String targetId, {
    AutoTransition? transition,
  }) {
    if (nodeById(sourceId) == null ||
        nodeById(targetId) == null ||
        sourceId == targetId ||
        GraphAlgorithms.wouldCreateCycle<AutoBranch>(
          sourceId,
          targetId,
          branches,
        )) {
      return false;
    }
    if (transition is FinishedTransition &&
        branches.any(
          (branch) =>
              branch.sourceId == sourceId &&
              branch.transition is FinishedTransition,
        )) {
      return false;
    }
    return true;
  }

  bool addNode(AutoNode node) {
    if (_allIds.contains(node.id) || _autoNodeError(node) != null) {
      return false;
    }
    nodes.add(node);
    ProjectEventRegistry.events.addAll(node.events);
    return true;
  }

  bool addBranch(AutoBranch branch) {
    if (_allIds.contains(branch.id) ||
        !canAddBranch(
          branch.sourceId,
          branch.targetId,
          transition: branch.transition,
        )) {
      return false;
    }
    branches.add(branch);
    ProjectEventRegistry.events.addAll(branch.events);
    _registerTransition(branch.transition);
    return true;
  }

  bool removeNode(String nodeId) {
    final node = nodeById(nodeId);
    if (node == null) {
      return false;
    }
    nodes.remove(node);
    branches.removeWhere(
      (branch) => branch.sourceId == nodeId || branch.targetId == nodeId,
    );
    return true;
  }

  bool removeBranch(String branchId) {
    final oldLength = branches.length;
    branches.removeWhere((branch) => branch.id == branchId);
    return branches.length != oldLength;
  }

  AutoGraphSnapshot snapshotGraph() => AutoGraphSnapshot(
    nodes: nodes,
    branches: branches,
    startingPose: startingPose,
    startingPoseInitialized: startingPoseInitialized,
  );

  void restoreGraph(AutoGraphSnapshot snapshot) {
    final restoredNodes = [for (final node in snapshot.nodes) node.clone()];
    final restoredBranches = [
      for (final branch in snapshot.branches) branch.clone(),
    ];
    final errors = _hardGraphErrors(restoredNodes, restoredBranches);
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.join('; '));
    }
    nodes = restoredNodes;
    branches = restoredBranches;
    startingPose = snapshot.startingPose;
    startingPoseInitialized = snapshot.startingPoseInitialized;
    _collectConditionNames();
    registerEvents();
  }

  Map<String, dynamic> toJson() {
    _validatedSourceVersion(sourceVersion);
    final graphDiagnostics = diagnostics;
    if (graphDiagnostics.hasHardErrors) {
      throw FormatException(
        'Invalid auto graph: ${graphDiagnostics.hardErrors.join('; ')}',
      );
    }
    _validatePose(startingPose);
    for (final node in nodes) {
      _validateEvents(node.events);
    }
    for (final branch in branches) {
      _validateEvents(branch.events);
    }
    return {
      'version': sourceVersion,
      'nodes': [for (final node in nodes) node.toJson()],
      'branches': [for (final branch in branches) branch.toJson()],
      'startingPose': {
        'position': startingPose.translation.toJson(),
        'rotation': startingPose.rotation.radians,
      },
      'startingPoseInitialized': startingPoseInitialized,
      'folder': folder,
    };
  }

  static Future<List<Path2Auto>> loadAllAutosInDir(
    String autosDir,
    FileSystem fs, {
    Iterable<path2.Path> paths = const [],
  }) async {
    final autos = <Path2Auto>[];
    final directory = fs.directory(autosDir);
    if (!directory.existsSync()) {
      return autos;
    }

    List<FileSystemEntity> entities;
    try {
      entities = directory.listSync();
    } catch (ex, stack) {
      Log.error('Failed to list autos directory: $autosDir', ex, stack);
      return autos;
    }

    for (final entity in entities) {
      if (!entity.path.endsWith('.auto')) {
        continue;
      }
      try {
        final file = fs.file(entity.path);
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Auto file must contain a JSON object');
        }
        if (decoded['choreoAuto'] == true) {
          continue;
        }
        _validatedSourceVersion(decoded['version']);
        final auto = Path2Auto.fromJson(
          decoded,
          basenameWithoutExtension(entity.path),
          autosDir,
          fs,
          paths: paths,
        );
        auto.lastModified = file.lastModifiedSync().toUtc();
        autos.add(auto);
      } catch (ex, stack) {
        Log.error('Failed to load Path2 auto: ${entity.path}', ex, stack);
      }
    }
    return autos;
  }

  Path2Auto duplicate(String newName) => Path2Auto(
    name: newName,
    nodes: [for (final node in nodes) node.clone()],
    branches: [for (final branch in branches) branch.clone()],
    startingPose: startingPose,
    startingPoseInitialized: startingPoseInitialized,
    autoDir: autoDir,
    fs: fs,
    folder: folder,
    sourceVersion: sourceVersion,
  );

  void rename(String newName) {
    final autoFile = fs.file(join(autoDir, '$name.auto'));
    if (autoFile.existsSync()) {
      autoFile.renameSync(join(autoDir, '$newName.auto'));
    }
    name = newName;
    lastModified = DateTime.now().toUtc();
  }

  void delete() {
    final autoFile = fs.file(join(autoDir, '$name.auto'));
    if (autoFile.existsSync()) {
      autoFile.deleteSync();
    }
  }

  void saveFile() {
    try {
      final autoFile = fs.file(join(autoDir, '$name.auto'));
      autoFile.parent.createSync(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      autoFile.writeAsStringSync(encoder.convert(toJson()));
      lastModified = DateTime.now().toUtc();
      Log.debug('Saved "$name.auto"');
    } catch (ex, stack) {
      Log.error('Failed to save Path2 auto: $name', ex, stack);
    }
  }

  /// Sets a user-selected pose and permanently marks this auto initialized.
  void setStartingPose(Pose2d pose) {
    _validatePose(pose);
    startingPose = pose;
    startingPoseInitialized = true;
  }

  /// Seeds once when the auto has one start node and its selected path has one
  /// valid root. A manual pose remains authoritative.
  bool initializeStartingPoseFromPaths(Iterable<path2.Path> paths) {
    if (startingPoseInitialized || rootNodes.length != 1) {
      return false;
    }
    final root = rootNodes.single;
    if (root is! PathAutoNode ||
        root.pathName == null ||
        root.pathName!.trim().isEmpty) {
      return false;
    }

    final resolvedPath = paths.firstWhereOrNull(
      (path) => path.name == root.pathName,
    );
    if (resolvedPath == null ||
        resolvedPath.diagnostics.hasHardErrors ||
        resolvedPath.rootNodes.length != 1) {
      return false;
    }

    final waypoint = resolvedPath.rootNodes.single.waypoint;
    setStartingPose(
      Pose2d(
        waypoint.position,
        waypoint is PoseWaypoint ? waypoint.rotation : const Rotation2d(),
      ),
    );
    return true;
  }

  void updatePathName(String oldPathName, String newPathName) {
    var changed = false;
    for (final node in nodes.whereType<PathAutoNode>()) {
      if (node.pathName == oldPathName) {
        node.pathName = newPathName;
        changed = true;
      }
    }
    if (changed) {
      saveFile();
    }
  }

  List<String> getAllPathNames() => [
    for (final node in nodes.whereType<PathAutoNode>())
      if (node.pathName case final String pathName
          when pathName.trim().isNotEmpty)
        pathName,
  ];

  bool hasEmptyPathNodes() => nodes.whereType<PathAutoNode>().any(
    (node) => node.pathName == null || node.pathName!.trim().isEmpty,
  );

  bool handleMissingPaths(Iterable<String> pathNames) {
    final available = pathNames.toSet();
    var changed = false;
    for (final node in nodes.whereType<PathAutoNode>()) {
      if (node.pathName != null && !available.contains(node.pathName)) {
        node.pathName = null;
        changed = true;
      }
    }
    return changed;
  }

  List<String> getAllConditionNames() => [
    for (final branch in branches)
      if (branch.transition case ConditionTransition(:final conditionName)
          when conditionName != null && conditionName.trim().isNotEmpty)
        conditionName,
  ];

  bool updateConditionName(String oldName, String? newName) {
    var changed = false;
    for (final branch in branches) {
      final transition = branch.transition;
      if (transition is ConditionTransition &&
          transition.conditionName == oldName) {
        transition.conditionName = newName;
        changed = true;
      }
    }
    ProjectConditionRegistry.register(newName);
    return changed;
  }

  Set<String> get _allIds => {
    for (final node in nodes) node.id,
    for (final branch in branches) branch.id,
  };

  void _collectConditionNames() {
    for (final branch in branches) {
      _registerTransition(branch.transition);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Path2Auto &&
      other.name == name &&
      const ListEquality<AutoNode>().equals(other.nodes, nodes) &&
      const ListEquality<AutoBranch>().equals(other.branches, branches) &&
      other.startingPose.x == startingPose.x &&
      other.startingPose.y == startingPose.y &&
      other.startingPose.rotation.radians == startingPose.rotation.radians &&
      other.startingPoseInitialized == startingPoseInitialized &&
      other.folder == folder &&
      other.sourceVersion == sourceVersion;

  @override
  int get hashCode => Object.hash(
    name,
    const ListEquality<AutoNode>().hash(nodes),
    const ListEquality<AutoBranch>().hash(branches),
    startingPose.x,
    startingPose.y,
    startingPose.rotation.radians,
    startingPoseInitialized,
    folder,
    sourceVersion,
  );

  static String _validatedSourceVersion(Object? value) {
    if (value is! String) {
      throw const FormatException('Auto version must be a string');
    }
    late final Version parsed;
    try {
      parsed = Version.parse(value);
    } catch (_) {
      throw FormatException('Invalid auto version: $value');
    }
    if (parsed < _minimumFileVersion) {
      throw FormatException(
        'Auto version $value is older than the minimum $fileVersion',
      );
    }
    return value;
  }
}

List<String> _hardGraphErrors(List<AutoNode> nodes, List<AutoBranch> branches) {
  final errors = <String>[];
  final seenIds = <String>{};
  for (final node in nodes) {
    final payloadError = _autoNodeError(node);
    if (payloadError != null) {
      errors.add(payloadError);
    }
    if (!seenIds.add(node.id)) {
      errors.add('Duplicate graph ID: ${node.id}');
    }
  }

  final nodeIds = {for (final node in nodes) node.id};
  final finishedBySource = <String, int>{};
  for (final branch in branches) {
    if (branch.id.trim().isEmpty ||
        branch.sourceId.trim().isEmpty ||
        branch.targetId.trim().isEmpty) {
      errors.add('Auto branch IDs must be nonempty');
    }
    if (!seenIds.add(branch.id)) {
      errors.add('Duplicate graph ID: ${branch.id}');
    }
    if (!nodeIds.contains(branch.sourceId)) {
      errors.add(
        'Branch ${branch.id} references missing source ${branch.sourceId}',
      );
    }
    if (!nodeIds.contains(branch.targetId)) {
      errors.add(
        'Branch ${branch.id} references missing target ${branch.targetId}',
      );
    }
    if (branch.sourceId == branch.targetId) {
      errors.add('Branch ${branch.id} is a self-link');
    }
    final transition = branch.transition;
    if (transition is ConditionTransition &&
        (!transition.previewDistanceMeters.isFinite ||
            transition.previewDistanceMeters < 0)) {
      errors.add(
        'Branch ${branch.id} has an invalid condition preview distance',
      );
    }
    if (transition is FinishedTransition) {
      finishedBySource.update(
        branch.sourceId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }
  for (final entry in finishedBySource.entries) {
    if (entry.value > 1) {
      errors.add(
        'Auto node ${entry.key} has more than one finished transition',
      );
    }
  }
  if (GraphAlgorithms.hasCycle<AutoNode, AutoBranch>(nodes, branches)) {
    errors.add('Auto graph contains a cycle');
  }
  return errors;
}

String? _autoNodeError(AutoNode node) {
  if (node.id.trim().isEmpty) {
    return 'Auto node ID must be nonempty';
  }
  if (!isFiniteOffset(node.editorPosition)) {
    return 'Auto node ${node.id} has an invalid editor position';
  }
  return null;
}

List<AutoNode> _nodesFromJson(Object? value) {
  if (value is! List) {
    throw const FormatException('Auto nodes must be a list');
  }
  return [for (final item in value) AutoNode.fromJson(item)];
}

List<AutoBranch> _branchesFromJson(Object? value) {
  if (value is! List) {
    throw const FormatException('Auto branches must be a list');
  }
  return [for (final item in value) AutoBranch.fromJson(item)];
}

Pose2d _poseFromJson(Object? value) {
  final json = _jsonObject(value, 'startingPose');
  final position = _jsonObject(json['position'], 'startingPose.position');
  final x = position['x'];
  final y = position['y'];
  final rotation = json['rotation'];
  if (x is! num ||
      y is! num ||
      rotation is! num ||
      !x.isFinite ||
      !y.isFinite ||
      !rotation.isFinite) {
    throw const FormatException(
      'startingPose must contain finite x, y, and rotation values',
    );
  }
  return Pose2d(Translation2d(x, y), Rotation2d.fromRadians(rotation));
}

void _validatePose(Pose2d pose) {
  if (!pose.x.isFinite || !pose.y.isFinite || !pose.rotation.radians.isFinite) {
    throw ArgumentError.value(pose, 'startingPose', 'Pose must be finite');
  }
}

String _requiredId(Map<String, dynamic> json, String key, String label) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$label must be a nonempty string');
  }
  return value;
}

void _validateId(String value, String label) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, label, 'Must be nonempty');
  }
}

Map<String, dynamic> _jsonObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('$label must be an object');
  }
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw FormatException('$label must have string keys');
  }
}

void _registerTransition(AutoTransition transition) {
  if (transition is ConditionTransition) {
    ProjectConditionRegistry.register(transition.conditionName);
  }
}

List<String> _eventsFromJson(Object? value) {
  if (value == null) return [];
  if (value is! List ||
      value.any((name) => name is! String || name.trim().isEmpty)) {
    throw const FormatException('Events must be a list of nonempty strings');
  }
  return List<String>.from(value);
}

void _validateEvents(List<String> events) {
  if (events.any((name) => name.trim().isEmpty)) {
    throw ArgumentError('Events must be nonempty strings');
  }
}
