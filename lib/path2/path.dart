import 'dart:convert';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:path/path.dart';
import 'package:pathplanner/path2/branch_event.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/services/project_event_registry.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:version/version.dart';

export 'package:pathplanner/path2/branch_event.dart';

const String fileVersion = '2027.1';

class PathNode implements GraphNodeData {
  @override
  final String id;
  Waypoint waypoint;
  @override
  Offset editorPosition;
  EndTolerance endTolerance;

  PathNode({
    String? id,
    required this.waypoint,
    required this.editorPosition,
    EndTolerance? endTolerance,
  }) : id = id ?? generateGraphId(),
       endTolerance = endTolerance ?? EndTolerance() {
    _validateId(this.id, 'Path node ID');
    validateFiniteOffset(editorPosition, 'editorPosition');
  }

  factory PathNode.fromJson(Object? value) {
    final json = _jsonObject(value, 'Path node');
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Path node ID must be a nonempty string');
    }
    final waypointJson = _jsonObject(json['waypoint'], 'Path node waypoint');
    return PathNode(
      id: id,
      waypoint: Waypoint.fromJson(waypointJson),
      editorPosition: editorPositionFromJson(json['editorPosition']),
      endTolerance: EndTolerance.fromJson(json['endTolerance']),
    );
  }

  PathNode clone() => PathNode(
    id: id,
    waypoint: waypoint.clone(),
    editorPosition: editorPosition,
    endTolerance: endTolerance.clone(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'waypoint': waypoint.toJson(),
    'editorPosition': editorPositionToJson(editorPosition),
    'endTolerance': endTolerance.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is PathNode &&
      other.id == id &&
      other.waypoint == waypoint &&
      other.editorPosition == editorPosition &&
      other.endTolerance == endTolerance;

  @override
  int get hashCode => Object.hash(id, waypoint, editorPosition, endTolerance);
}

class PathBranch implements GraphBranchData {
  @override
  final String id;
  @override
  final String sourceId;
  @override
  final String targetId;
  PathTransition transition;
  List<BranchEvent> events;

  PathBranch({
    String? id,
    required this.sourceId,
    required this.targetId,
    List<BranchEvent> events = const [],
    PathTransition? transition,
  }) : events = [for (final event in events) event.clone()],
       id = id ?? generateGraphId(),
       transition = transition ?? DistanceTransition() {
    _validateId(this.id, 'Path branch ID');
    _validateId(sourceId, 'Path branch source ID');
    _validateId(targetId, 'Path branch target ID');
  }

  factory PathBranch.fromJson(Object? value) {
    final json = _jsonObject(value, 'Path branch');
    return PathBranch(
      id: _requiredId(json, 'id', 'Path branch ID'),
      sourceId: _requiredId(json, 'sourceId', 'Path branch source ID'),
      targetId: _requiredId(json, 'targetId', 'Path branch target ID'),
      transition: PathTransition.fromJson(json['transition']),
      events: BranchEvent.listFromJson(json['events']),
    );
  }

  PathBranch clone() => PathBranch(
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
    'events': [for (final event in events) event.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is PathBranch &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.targetId == targetId &&
      other.transition == transition &&
      const ListEquality<BranchEvent>().equals(other.events, events);

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    targetId,
    transition,
    const ListEquality<BranchEvent>().hash(events),
  );
}

class PathGraphSnapshot {
  final List<PathNode> nodes;
  final List<PathBranch> branches;

  PathGraphSnapshot({
    required Iterable<PathNode> nodes,
    required Iterable<PathBranch> branches,
  }) : nodes = [for (final node in nodes) node.clone()],
       branches = [for (final branch in branches) branch.clone()];
}

class Path {
  static final Version _minimumFileVersion = Version.parse(fileVersion);

  String name;
  List<PathNode> nodes;
  List<PathBranch> branches;
  String? folder;

  /// The accepted version string read from disk.
  ///
  /// Keeping this verbatim prevents an explicit save from downgrading a file
  /// written by a newer compatible release.
  String sourceVersion;

  FileSystem fs;
  String pathDir;
  DateTime lastModified = DateTime.now().toUtc();

  Path({
    required this.name,
    required this.nodes,
    List<PathBranch>? branches,
    required this.fs,
    required this.pathDir,
    this.folder,
    this.sourceVersion = fileVersion,
  }) : branches = branches ?? [] {
    _validatedSourceVersion(sourceVersion);
    final graphDiagnostics = diagnostics;
    if (graphDiagnostics.hasHardErrors) {
      throw ArgumentError(graphDiagnostics.hardErrors.join('; '));
    }
    synchronizeInheritedTargets();
    _collectConditionNames();
    registerEvents();
  }

  factory Path.defaultPath({
    required String pathDir,
    required FileSystem fs,
    String name = 'New Path',
    String? folder,
  }) {
    final first = PathNode(
      waypoint: PoseWaypoint(
        position: const Translation2d(-6.0, 3.0),
        rotation: const Rotation2d(),
      ),
      editorPosition: const Offset(100, 80),
    );
    final second = PathNode(
      waypoint: PoseWaypoint(
        position: const Translation2d(-4.0, 2.0),
        rotation: const Rotation2d(),
      ),
      editorPosition: const Offset(100, 600),
    );
    return Path(
      name: name,
      nodes: [first, second],
      branches: [
        PathBranch(
          sourceId: first.id,
          targetId: second.id,
          transition: DistanceTransition(),
        ),
      ],
      fs: fs,
      pathDir: pathDir,
      folder: folder,
    );
  }

  factory Path.fromJson(
    Map<String, dynamic> json,
    String name,
    String pathsDir,
    FileSystem fs,
  ) {
    final sourceVersion = _validatedSourceVersion(json['version']);
    try {
      return Path(
        pathDir: pathsDir,
        fs: fs,
        name: name,
        nodes: _nodesFromJson(json['nodes']),
        branches: _branchesFromJson(json['branches']),
        folder: _optionalFolder(json['folder']),
        sourceVersion: sourceVersion,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid path graph: ${error.message}');
    }
  }

  void registerEvents() {
    for (final node in nodes) {
      ProjectEventRegistry.events.addAll(node.waypoint.events);
    }
    for (final branch in branches) {
      ProjectEventRegistry.events.addAll(
        branch.events.map((event) => event.name),
      );
    }
  }

  bool replaceEventName(String oldName, String? newName) {
    var changed = false;
    for (final node in nodes) {
      if (node.waypoint.events.contains(oldName)) {
        changed = true;
        node.waypoint.events = [
          for (final name in node.waypoint.events)
            if (name != oldName) name else if (newName != null) newName,
        ];
      }
    }
    for (final branch in branches) {
      if (branch.events.any((event) => event.name == oldName)) {
        changed = true;
        branch.events = [
          for (final event in branch.events)
            if (event.name != oldName)
              event
            else if (newName != null)
              BranchEvent(name: newName, position: event.position),
        ];
      }
    }
    if (changed) registerEvents();
    return changed;
  }

  String get version => sourceVersion;

  PathNode? nodeById(String id) =>
      nodes.firstWhereOrNull((node) => node.id == id);

  /// Direct point-towards parents, in the order their incoming branches are
  /// stored in the path file.
  List<PathNode> pointTowardsParentsOf(String nodeId) {
    final parents = <PathNode>[];
    final seenParentIds = <String>{};
    for (final branch in branches) {
      if (branch.targetId != nodeId || !seenParentIds.add(branch.sourceId)) {
        continue;
      }
      final parent = nodeById(branch.sourceId);
      if (parent?.waypoint is PointTowardsWaypoint) {
        parents.add(parent!);
      }
    }
    return parents;
  }

  /// The non-inheriting waypoint that owns [nodeId]'s editable target.
  PathNode? pointTowardsTargetOwner(String nodeId) {
    var current = nodeById(nodeId);
    if (current?.waypoint is! PointTowardsWaypoint) {
      return null;
    }

    final visited = <String>{};
    while (current != null && visited.add(current.id)) {
      final waypoint = current.waypoint as PointTowardsWaypoint;
      if (!waypoint.inheritTargetFromParent) {
        return current;
      }
      final parents = pointTowardsParentsOf(current.id);
      if (parents.isEmpty) {
        return current;
      }
      current = parents.first;
    }
    return current;
  }

  /// Updates the resolved target for [nodeId] and all waypoints inheriting it.
  ///
  /// Edits to an inheriting waypoint are redirected to its ultimate target
  /// owner so fields and field dragging behave identically.
  bool updatePointTowardsTarget(String nodeId, Translation2d target) {
    synchronizeInheritedTargets();
    final owner = pointTowardsTargetOwner(nodeId);
    final waypoint = owner?.waypoint;
    if (waypoint is! PointTowardsWaypoint ||
        waypoint.targetPosition == target) {
      return false;
    }
    waypoint.moveTarget(target.x, target.y);
    synchronizeInheritedTargets();
    return true;
  }

  /// Copies inherited targets into each waypoint so serialization is
  /// self-contained. Missing eligible parents disable inheritance while
  /// retaining the last resolved target.
  void synchronizeInheritedTargets() {
    final resolved = <String>{};
    final resolving = <String>{};

    void resolve(PathNode node) {
      if (resolved.contains(node.id)) {
        return;
      }
      final waypoint = node.waypoint;
      if (waypoint is! PointTowardsWaypoint) {
        resolved.add(node.id);
        return;
      }
      if (!resolving.add(node.id)) {
        return;
      }

      if (waypoint.inheritTargetFromParent) {
        final parents = pointTowardsParentsOf(node.id);
        if (parents.isEmpty) {
          waypoint.inheritTargetFromParent = false;
        } else {
          final parent = parents.first;
          resolve(parent);
          final parentWaypoint = parent.waypoint;
          if (parentWaypoint is PointTowardsWaypoint) {
            waypoint.targetPosition = parentWaypoint.targetPosition;
          }
        }
      }

      resolving.remove(node.id);
      resolved.add(node.id);
    }

    for (final node in nodes) {
      resolve(node);
    }
  }

  List<PathNode> get rootNodes =>
      GraphAlgorithms.roots<PathNode, PathBranch>(nodes, branches);

  List<PathNode> get leafNodes =>
      GraphAlgorithms.leaves<PathNode, PathBranch>(nodes, branches);

  bool isLeaf(String nodeId) =>
      nodeById(nodeId) != null &&
      !branches.any((branch) => branch.sourceId == nodeId);

  Set<String> reverseReachableNodeIds(String nodeId) {
    if (nodeById(nodeId) == null) {
      return {};
    }
    return GraphAlgorithms.reverseReachableNodeIds<PathBranch>(
      nodeId,
      branches,
    );
  }

  /// Nodes reachable from the single root, or an empty set for a draft that
  /// does not currently have exactly one root.
  Set<String> get reachableNodeIds {
    final roots = rootNodes;
    if (roots.length != 1) {
      return {};
    }
    return GraphAlgorithms.reachableNodeIds<PathBranch>(
      roots.single.id,
      branches,
    );
  }

  GraphDiagnostics get diagnostics {
    final hardErrors = _hardGraphErrors(nodes, branches);
    final draftWarnings = <String>[];
    final configurationWarnings = <String>[];

    if (nodes.isNotEmpty && hardErrors.isEmpty) {
      final roots = GraphAlgorithms.roots<PathNode, PathBranch>(
        nodes,
        branches,
      );
      if (roots.length != 1) {
        draftWarnings.add(
          'Path must have exactly one start node; found ${roots.length}',
        );
      } else {
        final reachable = GraphAlgorithms.reachableNodeIds<PathBranch>(
          roots.single.id,
          branches,
        );
        if (reachable.length != nodes.length) {
          draftWarnings.add('Some path nodes are unreachable from the start');
        }
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

  bool canAddBranch(String sourceId, String targetId) {
    if (nodeById(sourceId) == null ||
        nodeById(targetId) == null ||
        sourceId == targetId) {
      return false;
    }
    return !GraphAlgorithms.wouldCreateCycle<PathBranch>(
      sourceId,
      targetId,
      branches,
    );
  }

  bool addNode(PathNode node) {
    if (_allIds.contains(node.id) || _pathNodeError(node) != null) {
      return false;
    }
    nodes.add(node);
    return true;
  }

  bool addBranch(PathBranch branch) {
    if (_allIds.contains(branch.id) ||
        !canAddBranch(branch.sourceId, branch.targetId) ||
        _pathBranchPayloadError(branch) != null) {
      return false;
    }
    branches.add(branch);
    synchronizeInheritedTargets();
    _registerTransition(branch.transition);
    return true;
  }

  bool removeNode(String nodeId) {
    if (nodes.length <= 1) {
      return false;
    }
    final node = nodeById(nodeId);
    if (node == null) {
      return false;
    }
    nodes.remove(node);
    branches.removeWhere(
      (branch) => branch.sourceId == nodeId || branch.targetId == nodeId,
    );
    synchronizeInheritedTargets();
    return true;
  }

  bool removeBranch(String branchId) {
    final oldLength = branches.length;
    branches.removeWhere((branch) => branch.id == branchId);
    final changed = branches.length != oldLength;
    if (changed) {
      synchronizeInheritedTargets();
    }
    return changed;
  }

  PathGraphSnapshot snapshotGraph() =>
      PathGraphSnapshot(nodes: nodes, branches: branches);

  void restoreGraph(PathGraphSnapshot snapshot) {
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
    synchronizeInheritedTargets();
    _collectConditionNames();
    registerEvents();
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

  Map<String, dynamic> toJson() {
    _validatedSourceVersion(sourceVersion);
    synchronizeInheritedTargets();
    final graphDiagnostics = diagnostics;
    if (graphDiagnostics.hasHardErrors) {
      throw FormatException(
        'Invalid path graph: ${graphDiagnostics.hardErrors.join('; ')}',
      );
    }
    return {
      'version': sourceVersion,
      'nodes': [for (final node in nodes) node.toJson()],
      'branches': [for (final branch in branches) branch.toJson()],
      'folder': folder,
    };
  }

  void saveFile() {
    registerEvents();
    try {
      final pathFile = fs.file(join(pathDir, '$name.path'));
      pathFile.parent.createSync(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      pathFile.writeAsStringSync(encoder.convert(toJson()));
      lastModified = DateTime.now().toUtc();
    } catch (ex, stack) {
      Log.error('Failed to save path: $name', ex, stack);
    }
  }

  static Future<List<Path>> loadAllPathsInDir(
    String pathsDir,
    FileSystem fs,
  ) async {
    final paths = <Path>[];
    final directory = fs.directory(pathsDir);
    if (!directory.existsSync()) {
      return paths;
    }

    List<FileSystemEntity> entities;
    try {
      entities = directory.listSync();
    } catch (ex, stack) {
      Log.error('Failed to list paths directory: $pathsDir', ex, stack);
      return paths;
    }

    for (final entity in entities) {
      if (!entity.path.endsWith('.path')) {
        continue;
      }
      try {
        final pathFile = fs.file(entity.path);
        final decoded = jsonDecode(pathFile.readAsStringSync());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Path file must contain a JSON object');
        }
        _validatedSourceVersion(decoded['version']);
        final path = Path.fromJson(
          decoded,
          basenameWithoutExtension(entity.path),
          pathsDir,
          fs,
        );
        path.lastModified = pathFile.lastModifiedSync().toUtc();
        paths.add(path);
      } catch (ex, stack) {
        Log.error('Failed to load path: ${entity.path}', ex, stack);
      }
    }
    return paths;
  }

  void deletePath() {
    final pathFile = fs.file(join(pathDir, '$name.path'));
    if (pathFile.existsSync()) {
      pathFile.deleteSync();
    }
  }

  void renamePath(String newName) {
    final pathFile = fs.file(join(pathDir, '$name.path'));
    if (pathFile.existsSync()) {
      pathFile.renameSync(join(pathDir, '$newName.path'));
    }
    name = newName;
    lastModified = DateTime.now().toUtc();
  }

  Path duplicate(String newName) => Path(
    name: newName,
    nodes: [for (final node in nodes) node.clone()],
    branches: [for (final branch in branches) branch.clone()],
    fs: fs,
    pathDir: pathDir,
    folder: folder,
    sourceVersion: sourceVersion,
  );

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
      other is Path &&
      other.name == name &&
      const ListEquality<PathNode>().equals(other.nodes, nodes) &&
      const ListEquality<PathBranch>().equals(other.branches, branches) &&
      other.folder == folder &&
      other.sourceVersion == sourceVersion;

  @override
  int get hashCode => Object.hash(
    name,
    const ListEquality<PathNode>().hash(nodes),
    const ListEquality<PathBranch>().hash(branches),
    folder,
    sourceVersion,
  );

  static String _validatedSourceVersion(Object? value) {
    if (value is! String) {
      throw const FormatException('Path version must be a string');
    }
    late final Version parsed;
    try {
      parsed = Version.parse(value);
    } catch (_) {
      throw FormatException('Invalid path version: $value');
    }
    if (parsed < _minimumFileVersion) {
      throw FormatException(
        'Path version $value is older than the minimum $fileVersion',
      );
    }
    return value;
  }
}

List<String> _hardGraphErrors(List<PathNode> nodes, List<PathBranch> branches) {
  final errors = <String>[];
  if (nodes.isEmpty) {
    errors.add('A path must have at least one node');
  }

  final seenIds = <String>{};
  for (final node in nodes) {
    final payloadError = _pathNodeError(node);
    if (payloadError != null) {
      errors.add(payloadError);
    }
    if (!seenIds.add(node.id)) {
      errors.add('Duplicate graph ID: ${node.id}');
    }
  }
  final nodeIds = {for (final node in nodes) node.id};
  for (final branch in branches) {
    final payloadError = _pathBranchPayloadError(branch);
    if (payloadError != null) {
      errors.add(payloadError);
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
  }

  if (GraphAlgorithms.hasCycle<PathNode, PathBranch>(nodes, branches)) {
    errors.add('Path graph contains a cycle');
  }
  return errors;
}

String? _pathNodeError(PathNode node) {
  if (node.id.trim().isEmpty) {
    return 'Path node ID must be nonempty';
  }
  if (!isFiniteOffset(node.editorPosition)) {
    return 'Path node ${node.id} has an invalid editor position';
  }
  final waypoint = node.waypoint;
  if (!waypoint.position.x.isFinite ||
      !waypoint.position.y.isFinite ||
      !waypoint.maxVelocity.isFinite ||
      waypoint.maxVelocity < 0 ||
      !waypoint.maxAngularVelocity.isFinite ||
      waypoint.maxAngularVelocity < 0 ||
      !waypoint.maxAngularAcceleration.isFinite ||
      waypoint.maxAngularAcceleration < 0 ||
      (waypoint is PoseWaypoint && !waypoint.rotation.radians.isFinite) ||
      (waypoint is PointTowardsWaypoint &&
          (!waypoint.targetPosition.x.isFinite ||
              !waypoint.targetPosition.y.isFinite ||
              !waypoint.rotationOffset.radians.isFinite)) ||
      (waypoint is! PoseWaypoint &&
          waypoint is! TranslationWaypoint &&
          waypoint is! PointTowardsWaypoint)) {
    return 'Path node ${node.id} has an invalid waypoint payload';
  }
  if (!node.endTolerance.distanceMeters.isFinite ||
      node.endTolerance.distanceMeters < 0 ||
      !node.endTolerance.angleDegrees.isFinite ||
      node.endTolerance.angleDegrees < 0) {
    return 'Path node ${node.id} has invalid end tolerances';
  }
  return null;
}

String? _pathBranchPayloadError(PathBranch branch) {
  if (branch.id.trim().isEmpty ||
      branch.sourceId.trim().isEmpty ||
      branch.targetId.trim().isEmpty) {
    return 'Path branch IDs must be nonempty';
  }
  final transition = branch.transition;
  if (transition is DistanceTransition &&
      (!transition.distanceMeters.isFinite || transition.distanceMeters < 0)) {
    return 'Branch ${branch.id} has an invalid distance transition';
  }
  if (transition is ConditionTransition &&
      (!transition.previewDistanceMeters.isFinite ||
          transition.previewDistanceMeters < 0)) {
    return 'Branch ${branch.id} has an invalid condition preview distance';
  }
  return null;
}

List<PathNode> _nodesFromJson(Object? value) {
  if (value is! List || value.isEmpty) {
    throw const FormatException('A path must have at least one node');
  }
  return [for (final item in value) PathNode.fromJson(item)];
}

List<PathBranch> _branchesFromJson(Object? value) {
  if (value is! List) {
    throw const FormatException('Path branches must be a list');
  }
  return [for (final item in value) PathBranch.fromJson(item)];
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

String? _optionalFolder(Object? value) {
  if (value == null || value is String) {
    return value as String?;
  }
  throw const FormatException('Path folder must be a string or null');
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

void _registerTransition(PathTransition transition) {
  if (transition is ConditionTransition) {
    ProjectConditionRegistry.register(transition.conditionName);
  }
}
