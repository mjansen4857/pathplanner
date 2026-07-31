import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/path.dart' as path2;
import 'package:pathplanner/path2/simulation/path2_simulator.dart';
import 'package:pathplanner/path2/simulation/simulation_state.dart';
import 'package:pathplanner/path2/waypoint.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/trajectory/config.dart';
import 'package:pathplanner/util/path_painter_util.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/widgets/editor/graph_editor/path_graph_node_card.dart';
import 'package:pathplanner/widgets/editor/graph_editor/visual_graph_editor.dart';
import 'package:pathplanner/widgets/editor/path2_painter.dart';
import 'package:pathplanner/widgets/editor/preview_seekbar.dart';
import 'package:pathplanner/widgets/field_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class SplitPath2Editor extends StatefulWidget {
  final SharedPreferences prefs;
  final path2.Path path;
  final FieldImage fieldImage;
  final ChangeStack undoStack;
  final VoidCallback? onPathChanged;
  final Future<Path2SimulationOutcome> Function(
    path2.Path path,
    RobotConfig robotConfig,
  )? simulatePath;

  const SplitPath2Editor({
    super.key,
    required this.prefs,
    required this.path,
    required this.fieldImage,
    required this.undoStack,
    this.onPathChanged,
    this.simulatePath,
  });

  @override
  State<SplitPath2Editor> createState() => _SplitPath2EditorState();
}

class _SplitPath2EditorState extends State<SplitPath2Editor>
    with TickerProviderStateMixin {
  final MultiSplitViewController _splitController = MultiSplitViewController();
  final VisualGraphController _graphController = VisualGraphController();

  late final AnimationController _previewController;
  late bool _graphOnRight;
  late final Size _robotSize;
  late final Translation2d _bumperOffset;
  Path2GraphSimulationResult? _simulation;
  bool _previewPaused = false;
  int _simulationGeneration = 0;

  String? _hoveredNodeId;
  String? _selectedNodeId;
  String? _draggedNodeId;
  String? _draggedRotationNodeId;
  path2.PathGraphSnapshot? _fieldDragBefore;
  Waypoint? _dragOldWaypoint;
  Rotation2d? _dragOldRotation;
  Offset? _panDownPosition;

  Set<String>? get _visibleFieldNodeIds => _hoveredNodeId == null
      ? null
      : widget.path.reverseReachableNodeIds(_hoveredNodeId!);

  bool _isNodeVisibleOnField(String nodeId) =>
      _visibleFieldNodeIds?.contains(nodeId) ?? true;

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(vsync: this, value: 0);
    _graphOnRight =
        widget.prefs.getBool(PrefsKeys.treeOnRight) ?? Defaults.treeOnRight;
    _robotSize = Size(
      widget.prefs.getDouble(PrefsKeys.robotWidth) ?? Defaults.robotWidth,
      widget.prefs.getDouble(PrefsKeys.robotLength) ?? Defaults.robotLength,
    );
    _bumperOffset = Translation2d(
      widget.prefs.getDouble(PrefsKeys.bumperOffsetX) ?? Defaults.bumperOffsetX,
      widget.prefs.getDouble(PrefsKeys.bumperOffsetY) ?? Defaults.bumperOffsetY,
    );

    final graphWeight = widget.prefs.getDouble(PrefsKeys.editorTreeWeight) ??
        Defaults.editorTreeWeight;
    _splitController.areas = [
      Area(
        weight: _graphOnRight ? 1 - graphWeight : graphWeight,
        minimalWeight: 0.35,
      ),
      Area(
        weight: _graphOnRight ? graphWeight : 1 - graphWeight,
        minimalWeight: 0.35,
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _simulatePath());
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final field = _buildFieldPane(colorScheme);
    final graph = _buildGraphPane(colorScheme);

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerPainter: DividerPainters.grooved1(
          color: colorScheme.surfaceContainerHighest,
          highlightedColor: colorScheme.primary,
        ),
      ),
      child: MultiSplitView(
        axis: Axis.horizontal,
        controller: _splitController,
        onWeightChange: _saveGraphWeight,
        children: _graphOnRight ? [field, graph] : [graph, field],
      ),
    );
  }

  Widget _buildFieldPane(ColorScheme colorScheme) {
    final visibleNodeIds = _visibleFieldNodeIds;
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 10,
            boundaryMargin: const EdgeInsets.all(200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.fieldImage.defaultSize.width /
                      widget.fieldImage.defaultSize.height,
                  child: GestureDetector(
                    key: const ValueKey('path2FieldGesture'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _handleFieldTapDown,
                    onPanDown: (details) =>
                        _panDownPosition = details.localPosition,
                    onPanStart: _handleFieldPanStart,
                    onPanUpdate: _handleFieldPanUpdate,
                    onPanEnd: (_) => _finishFieldDrag(),
                    onPanCancel: _cancelFieldDrag,
                    child: Stack(
                      children: [
                        widget.fieldImage.getWidget(),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: Path2Painter(
                              colorScheme: colorScheme,
                              paintPaths: [
                                Path2PaintPath(
                                  path: widget.path,
                                  visibleNodeIds: visibleNodeIds,
                                ),
                              ],
                              fieldImage: widget.fieldImage,
                              prefs: widget.prefs,
                              hoveredNodeId: _hoveredNodeId,
                              selectedNodeId: _selectedNodeId,
                              simulations: _simulation?.traversals ?? const [],
                              animation: _previewController.view,
                              simulationDurationSeconds:
                                  _simulation?.totalTimeSeconds ?? 0,
                            ),
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
        PreviewSeekbar(
          previewController: _previewController,
          onPauseStateChanged: (paused) => _previewPaused = paused,
          totalPathTime: _simulation?.totalTimeSeconds ?? 0,
          enabled: _simulation != null,
        ),
      ],
    );
  }

  Widget _buildGraphPane(ColorScheme colorScheme) {
    final diagnostics = widget.path.diagnostics;
    final selectedNode =
        _selectedNodeId == null ? null : widget.path.nodeById(_selectedNodeId!);
    final runtimesByLeaf =
        _simulation?.runtimesByLeafNodeId ?? const <String, List<double>>{};
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: _graphOnRight ? const Radius.circular(12) : Radius.zero,
          topRight: _graphOnRight ? Radius.zero : const Radius.circular(12),
          bottomLeft: _graphOnRight ? const Radius.circular(12) : Radius.zero,
          bottomRight: _graphOnRight ? Radius.zero : const Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                PopupMenuButton<_WaypointKind>(
                  key: const ValueKey('addPathNodeButton'),
                  tooltip: 'Add Waypoint',
                  icon: const Icon(Icons.add_location_alt_outlined),
                  onSelected: _addToolbarNode,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _WaypointKind.pose,
                      child: ListTile(
                        leading: Icon(Icons.explore_outlined),
                        title: Text('Pose waypoint'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _WaypointKind.translation,
                      child: ListTile(
                        leading: Icon(Icons.location_on_outlined),
                        title: Text('Translation waypoint'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Expanded(child: _buildDiagnostics(diagnostics, colorScheme)),
                Tooltip(
                  message: 'Move to Other Side',
                  waitDuration: const Duration(milliseconds: 500),
                  child: IconButton(
                    onPressed: _swapGraphSide,
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: VisualGraphEditor(
                      controller: _graphController,
                      nodes: [
                        for (final node in widget.path.nodes)
                          VisualGraphNode(
                            id: node.id,
                            position: node.editorPosition,
                            size: PathGraphNodeCard.sizeFor(widget.path, node),
                            child: PathGraphNodeCard(
                              path: widget.path,
                              node: node,
                              selected: node.id == _selectedNodeId,
                              onDelete: _deleteNode,
                              onHovered: (id) {
                                if (_hoveredNodeId != id) {
                                  setState(() => _hoveredNodeId = id);
                                }
                              },
                              onSelected: (id) {
                                if (_selectedNodeId != id) {
                                  setState(() => _selectedNodeId = id);
                                }
                              },
                              estimatedRuntimeSeconds:
                                  runtimesByLeaf[node.id] ?? const [],
                            ),
                          ),
                      ],
                      branches: [
                        for (final branch in widget.path.branches)
                          VisualGraphBranch(
                            id: branch.id,
                            sourceId: branch.sourceId,
                            targetId: branch.targetId,
                            badge: _transitionBadge(branch.transition),
                          ),
                      ],
                      onNodeMoved: (id, _, position) => _editNode(
                        id,
                        (node) => node.editorPosition = position,
                      ),
                      onConnect: _connectNodes,
                      onConnectToEmpty: _connectToNewNode,
                      onBranchTap: (id, _) => _editBranch(id),
                      onCanvasTap: () {
                        if (_selectedNodeId != null) {
                          setState(() => _selectedNodeId = null);
                        }
                      },
                    ),
                  ),
                  if (selectedNode != null)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      width: min(370, constraints.maxWidth - 32),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: min(
                            540,
                            max(160, constraints.maxHeight - 32),
                          ),
                        ),
                        child: PathGraphNodeSettingsPanel(
                          path: widget.path,
                          node: selectedNode,
                          onEdit: _editNode,
                          onClose: () => setState(() => _selectedNodeId = null),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnostics(
    GraphDiagnostics diagnostics,
    ColorScheme colorScheme,
  ) {
    if (!diagnostics.hasWarnings && !diagnostics.hasHardErrors) {
      return const SizedBox.shrink();
    }
    final messages = [
      ...diagnostics.hardErrors,
      ...diagnostics.warnings,
    ];
    return Tooltip(
      message: messages.join('\n'),
      child: Container(
        key: const ValueKey('pathGraphDiagnostics'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: diagnostics.hasHardErrors
              ? colorScheme.errorContainer
              : Colors.amber.withAlpha(45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 17,
              color: diagnostics.hasHardErrors
                  ? colorScheme.error
                  : Colors.amber.shade800,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                messages.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transitionBadge(PathTransition transition) {
    return switch (transition) {
      DistanceTransition(:final distanceMeters) => Text(
          '${distanceMeters.toStringAsFixed(2)} m',
          key: const ValueKey('distanceTransitionBadge'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ConditionTransition(:final conditionName) => Row(
          key: const ValueKey('conditionTransitionBadge'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '? ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Flexible(
              child: Text(
                conditionName?.trim().isNotEmpty ?? false
                    ? conditionName!
                    : 'Unset',
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
    };
  }

  void _addToolbarNode(_WaypointKind kind) {
    final fieldSize = widget.fieldImage.getFieldSizeMeters();
    final graphCenter =
        _graphController.viewportCenterInScene ?? const Offset(300, 250);
    final node = path2.PathNode(
      waypoint: _newWaypoint(
        kind,
        Translation2d(fieldSize.width / 2, fieldSize.height / 2),
      ),
      editorPosition: Offset.zero,
    );
    const cardSize = PathGraphNodeCard.cardSize;
    node.editorPosition =
        graphCenter - Offset(cardSize.width / 2, cardSize.height / 2);
    _commitGraphMutation(() => widget.path.addNode(node));
    setState(() => _selectedNodeId = node.id);
  }

  Future<void> _connectNodes(GraphConnectionRequest request) async {
    if (!widget.path.canAddBranch(request.sourceId, request.targetId)) {
      _showRejectedConnection();
      return;
    }
    final result = await showDialog<_PathTransitionDialogResult>(
      context: context,
      builder: (context) => _PathTransitionDialog(
        initialTransition: DistanceTransition(),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _commitGraphMutation(
      () => widget.path.addBranch(
        path2.PathBranch(
          sourceId: request.sourceId,
          targetId: request.targetId,
          transition: result.transition,
        ),
      ),
    );
  }

  Future<void> _connectToNewNode(GraphEmptyConnectionRequest request) async {
    final existing = widget.path.nodeById(request.nodeId);
    if (existing == null) {
      return;
    }
    final result = await showDialog<_PathTransitionDialogResult>(
      context: context,
      builder: (context) => _PathTransitionDialog(
        initialTransition: DistanceTransition(),
        chooseWaypointKind: true,
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    final position = _offsetWaypointPosition(existing.waypoint.position);
    final kind = result.waypointKind ?? _WaypointKind.translation;
    final waypoint = _newWaypoint(kind, position);
    const newNodeSize = PathGraphNodeCard.cardSize;
    final cardOffset = request.existingNodeIsSource
        ? Offset(
            newNodeSize.width / 2,
            0,
          )
        : Offset(
            newNodeSize.width / 2,
            newNodeSize.height,
          );
    final node = path2.PathNode(
      waypoint: waypoint,
      editorPosition: request.scenePosition - cardOffset,
    );
    final branch = path2.PathBranch(
      sourceId: request.existingNodeIsSource ? existing.id : node.id,
      targetId: request.existingNodeIsSource ? node.id : existing.id,
      transition: result.transition,
    );
    _commitGraphMutation(() {
      if (!widget.path.addNode(node)) {
        return false;
      }
      if (!widget.path.addBranch(branch)) {
        widget.path.removeNode(node.id);
        return false;
      }
      return true;
    });
    setState(() => _selectedNodeId = node.id);
  }

  Future<void> _editBranch(String branchId) async {
    final branch = _branchById(branchId);
    if (branch == null) {
      return;
    }
    final result = await showDialog<_PathTransitionDialogResult>(
      context: context,
      builder: (context) => _PathTransitionDialog(
        initialTransition: branch.transition,
        allowDelete: true,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.delete) {
      _commitGraphMutation(() => widget.path.removeBranch(branchId));
      return;
    }
    _commitGraphMutation(() {
      final current = _branchById(branchId);
      if (current == null) {
        return false;
      }
      current.transition = result.transition;
      if (result.transition case ConditionTransition(:final conditionName)) {
        ProjectConditionRegistry.register(conditionName);
      }
      return true;
    });
  }

  path2.PathBranch? _branchById(String id) {
    for (final branch in widget.path.branches) {
      if (branch.id == id) {
        return branch;
      }
    }
    return null;
  }

  void _editNode(
    String nodeId,
    void Function(path2.PathNode node) edit,
  ) {
    _commitGraphMutation(() {
      final node = widget.path.nodeById(nodeId);
      if (node == null) {
        return false;
      }
      edit(node);
      return true;
    });
  }

  void _deleteNode(String nodeId) {
    _commitGraphMutation(() => widget.path.removeNode(nodeId));
    if (_selectedNodeId == nodeId || _hoveredNodeId == nodeId) {
      setState(() {
        if (_selectedNodeId == nodeId) {
          _selectedNodeId = null;
        }
        if (_hoveredNodeId == nodeId) {
          _hoveredNodeId = null;
        }
      });
    }
  }

  void _handleFieldTapDown(TapDownDetails details) {
    FocusManager.instance.primaryFocus?.unfocus();
    final point = Translation2d(
      _xPixelsToMeters(details.localPosition.dx),
      _yPixelsToMeters(details.localPosition.dy),
    );
    final hitRadius = _pixelsToMeters(
      PathPainterUtil.uiPointSizeToPixels(
        25,
        Path2Painter.scale,
        widget.fieldImage,
      ),
    );
    for (final node in widget.path.nodes.reversed) {
      if (!_isNodeVisibleOnField(node.id)) {
        continue;
      }
      if (node.waypoint.isPointInAnchor(point.x, point.y, hitRadius)) {
        setState(() => _selectedNodeId = node.id);
        _graphController.centerNode(node.id);
        return;
      }
    }
    final rotationNodeId = _rotationHandleHitTest(point.x, point.y);
    if (rotationNodeId != null) {
      setState(() => _selectedNodeId = rotationNodeId);
      _graphController.centerNode(rotationNodeId);
      return;
    }
    setState(() => _selectedNodeId = null);
  }

  void _handleFieldPanStart(DragStartDetails details) {
    final startPosition = _panDownPosition ?? details.localPosition;
    _panDownPosition = null;
    final x = _xPixelsToMeters(startPosition.dx);
    final y = _yPixelsToMeters(startPosition.dy);
    final hitRadius = _pixelsToMeters(
      PathPainterUtil.uiPointSizeToPixels(
        25,
        Path2Painter.scale,
        widget.fieldImage,
      ),
    );

    for (final node in widget.path.nodes.reversed) {
      if (!_isNodeVisibleOnField(node.id)) {
        continue;
      }
      if (node.waypoint.startDragging(x, y, hitRadius)) {
        _fieldDragBefore = widget.path.snapshotGraph();
        _draggedNodeId = node.id;
        _dragOldWaypoint = node.waypoint.clone();
        setState(() => _selectedNodeId = node.id);
        return;
      }
    }

    final rotationId = _rotationHandleHitTest(x, y);
    final rotationNode =
        rotationId == null ? null : widget.path.nodeById(rotationId)?.waypoint;
    if (rotationNode is PoseWaypoint) {
      _fieldDragBefore = widget.path.snapshotGraph();
      _draggedRotationNodeId = rotationId;
      _dragOldRotation = rotationNode.rotation;
      setState(() => _selectedNodeId = rotationId);
    }
  }

  void _handleFieldPanUpdate(DragUpdateDetails details) {
    final draggedNodeId = _draggedNodeId;
    if (draggedNodeId != null) {
      final dragged = widget.path.nodeById(draggedNodeId)?.waypoint;
      if (dragged == null) {
        return;
      }
      final target = _clampedFieldPosition(details.localPosition);
      num targetX = target.x;
      num targetY = target.y;
      final snapSetting = widget.prefs.getBool(PrefsKeys.snapToGuidelines) ??
          Defaults.snapToGuidelines;
      final ctrlHeld = HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlRight);
      if (snapSetting ^ ctrlHeld) {
        num? closestX;
        num? closestY;
        for (final node in widget.path.nodes) {
          final waypoint = node.waypoint;
          if (node.id == draggedNodeId || !_isNodeVisibleOnField(node.id)) {
            continue;
          }
          if (closestX == null ||
              (targetX - waypoint.position.x).abs() <
                  (targetX - closestX).abs()) {
            closestX = waypoint.position.x;
          }
          if (closestY == null ||
              (targetY - waypoint.position.y).abs() <
                  (targetY - closestY).abs()) {
            closestY = waypoint.position.y;
          }
        }
        if (closestX != null && (targetX - closestX).abs() < 0.1) {
          targetX = closestX;
        }
        if (closestY != null && (targetY - closestY).abs() < 0.1) {
          targetY = closestY;
        }
      }
      setState(() => dragged.dragUpdate(targetX, targetY));
      return;
    }

    final rotationId = _draggedRotationNodeId;
    final waypoint =
        rotationId == null ? null : widget.path.nodeById(rotationId)?.waypoint;
    if (waypoint is PoseWaypoint) {
      final x = _xPixelsToMeters(details.localPosition.dx);
      final y = _yPixelsToMeters(details.localPosition.dy);
      setState(() {
        waypoint.rotation = Rotation2d.fromComponents(
          x - waypoint.position.x,
          y - waypoint.position.y,
        );
      });
    }
  }

  void _finishFieldDrag() {
    _panDownPosition = null;
    final draggedId = _draggedNodeId;
    if (draggedId != null) {
      final waypoint = widget.path.nodeById(draggedId)?.waypoint;
      waypoint?.stopDragging();
      final changed = waypoint != null && waypoint != _dragOldWaypoint;
      _draggedNodeId = null;
      _dragOldWaypoint = null;
      _finishTransientGraphEdit(changed);
      return;
    }

    final rotationId = _draggedRotationNodeId;
    if (rotationId != null) {
      final waypoint = widget.path.nodeById(rotationId)?.waypoint;
      final changed =
          waypoint is PoseWaypoint && waypoint.rotation != _dragOldRotation;
      _draggedRotationNodeId = null;
      _dragOldRotation = null;
      _finishTransientGraphEdit(changed);
    }
  }

  void _cancelFieldDrag() {
    final before = _fieldDragBefore;
    _draggedNodeId = null;
    _draggedRotationNodeId = null;
    _dragOldWaypoint = null;
    _dragOldRotation = null;
    _fieldDragBefore = null;
    if (before != null) {
      setState(() => widget.path.restoreGraph(before));
    }
  }

  void _finishTransientGraphEdit(bool changed) {
    final before = _fieldDragBefore;
    _fieldDragBefore = null;
    if (before == null || !changed) {
      return;
    }
    final after = widget.path.snapshotGraph();
    widget.path.restoreGraph(before);
    _pushSnapshotChange(before, after);
  }

  String? _rotationHandleHitTest(num x, num y) {
    final hitRadius = _pixelsToMeters(
      PathPainterUtil.uiPointSizeToPixels(
        15,
        Path2Painter.scale,
        widget.fieldImage,
      ),
    );
    final pointer = Translation2d(x, y);
    for (final node in widget.path.nodes.reversed) {
      if (!_isNodeVisibleOnField(node.id)) {
        continue;
      }
      final waypoint = node.waypoint;
      if (waypoint is PoseWaypoint &&
          _rotationHandlePosition(waypoint).getDistance(pointer) < hitRadius) {
        return node.id;
      }
    }
    return null;
  }

  Translation2d _rotationHandlePosition(PoseWaypoint waypoint) {
    final handleOffset = Translation2d(
      (_robotSize.height / 2) + _bumperOffset.x,
      _bumperOffset.y,
    ).rotateBy(waypoint.rotation);
    return waypoint.position + handleOffset;
  }

  Translation2d _clampedFieldPosition(Offset localPosition) {
    final size = widget.fieldImage.getFieldSizeMeters();
    return Translation2d(
      _xPixelsToMeters(localPosition.dx).clamp(0, size.width),
      _yPixelsToMeters(localPosition.dy).clamp(0, size.height),
    );
  }

  Translation2d _offsetWaypointPosition(Translation2d origin) {
    final size = widget.fieldImage.getFieldSizeMeters();
    var x = origin.x + 1;
    if (x > size.width) {
      x = origin.x - 1;
    }
    return Translation2d(
      x.clamp(0, size.width),
      origin.y.clamp(0, size.height),
    );
  }

  Waypoint _newWaypoint(_WaypointKind kind, Translation2d position) {
    return switch (kind) {
      _WaypointKind.pose => PoseWaypoint(
          position: position,
          rotation: const Rotation2d(),
        ),
      _WaypointKind.translation => TranslationWaypoint(position: position),
    };
  }

  void _showRejectedConnection() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('That branch would create a cycle.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _commitGraphMutation(bool Function() mutation) {
    final before = widget.path.snapshotGraph();
    if (!mutation()) {
      widget.path.restoreGraph(before);
      return;
    }
    final after = widget.path.snapshotGraph();
    widget.path.restoreGraph(before);
    _pushSnapshotChange(before, after);
  }

  void _pushSnapshotChange(
    path2.PathGraphSnapshot before,
    path2.PathGraphSnapshot after,
  ) {
    widget.undoStack.add(
      Change<path2.PathGraphSnapshot>(
        before,
        () => _restoreGraph(after),
        _restoreGraph,
      ),
    );
  }

  void _restoreGraph(path2.PathGraphSnapshot snapshot) {
    setState(() {
      widget.path.restoreGraph(snapshot);
      _saveAndNotify();
    });
  }

  void _saveAndNotify() {
    widget.path.saveFile();
    widget.onPathChanged?.call();
    _simulatePath();
  }

  Future<void> _simulatePath() async {
    final generation = ++_simulationGeneration;
    final previous = _simulation;
    final previousTime = previous == null
        ? 0.0
        : _previewController.value * previous.totalTimeSeconds;
    late final Path2SimulationOutcome outcome;
    try {
      outcome = await (widget.simulatePath ??
          Path2Simulator.simulatePathInBackground)(
        widget.path,
        RobotConfig.fromPrefs(widget.prefs),
      );
    } catch (error) {
      outcome = Path2SimulationOutcome.failed(
        Path2SimulationFailure(
          Path2SimulationFailureKind.invalidConfiguration,
          error.toString(),
        ),
      );
    }
    if (!mounted || generation != _simulationGeneration) {
      return;
    }

    final result = outcome.result;
    if (result == null) {
      _previewController
        ..stop()
        ..reset();
      setState(() => _simulation = null);
      return;
    }

    setState(() => _simulation = result);
    _previewController
      ..stop()
      ..duration = Duration(
        milliseconds: max(
          1,
          (result.totalTimeSeconds * 1000).round(),
        ),
      );
    if (_previewPaused) {
      _previewController.value = result.totalTimeSeconds <= 0
          ? 0
          : (previousTime / result.totalTimeSeconds).clamp(0.0, 1.0).toDouble();
    } else {
      _previewController
        ..value = 0
        ..repeat();
    }
  }

  void _swapGraphSide() {
    setState(() {
      _graphOnRight = !_graphOnRight;
      widget.prefs.setBool(PrefsKeys.treeOnRight, _graphOnRight);
      _splitController.areas = _splitController.areas.reversed.toList();
    });
  }

  void _saveGraphWeight() {
    final weight = _graphOnRight
        ? _splitController.areas[1].weight
        : _splitController.areas[0].weight;
    widget.prefs.setDouble(PrefsKeys.editorTreeWeight, weight ?? 0.5);
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels / Path2Painter.scale) / widget.fieldImage.pixelsPerMeter) -
        widget.fieldImage.marginMeters;
  }

  double _yPixelsToMeters(double pixels) {
    return ((widget.fieldImage.defaultSize.height -
                pixels / Path2Painter.scale) /
            widget.fieldImage.pixelsPerMeter) -
        widget.fieldImage.marginMeters;
  }

  double _pixelsToMeters(double pixels) =>
      (pixels / Path2Painter.scale) / widget.fieldImage.pixelsPerMeter;
}

enum _WaypointKind { pose, translation }

class _PathTransitionDialogResult {
  final PathTransition transition;
  final _WaypointKind? waypointKind;
  final bool delete;

  const _PathTransitionDialogResult({
    required this.transition,
    this.waypointKind,
    this.delete = false,
  });
}

class _PathTransitionDialog extends StatefulWidget {
  final PathTransition initialTransition;
  final bool allowDelete;
  final bool chooseWaypointKind;

  const _PathTransitionDialog({
    required this.initialTransition,
    this.allowDelete = false,
    this.chooseWaypointKind = false,
  });

  @override
  State<_PathTransitionDialog> createState() => _PathTransitionDialogState();
}

class _PathTransitionDialogState extends State<_PathTransitionDialog> {
  late String _transitionType;
  late _WaypointKind _waypointKind;
  late final TextEditingController _distanceController;
  late final TextEditingController _conditionController;
  late final TextEditingController _previewDistanceController;
  late final FocusNode _conditionFocusNode;
  String? _distanceError;
  String? _previewDistanceError;

  @override
  void initState() {
    super.initState();
    _transitionType = widget.initialTransition is ConditionTransition
        ? 'condition'
        : 'distance';
    _waypointKind = _WaypointKind.translation;
    _distanceController = TextEditingController(
      text: widget.initialTransition is DistanceTransition
          ? (widget.initialTransition as DistanceTransition)
              .distanceMeters
              .toString()
          : DistanceTransition.defaultDistanceMeters.toString(),
    );
    _conditionController = TextEditingController(
      text: widget.initialTransition is ConditionTransition
          ? (widget.initialTransition as ConditionTransition).conditionName ??
              ''
          : '',
    );
    _previewDistanceController = TextEditingController(
      text: widget.initialTransition is ConditionTransition
          ? (widget.initialTransition as ConditionTransition)
              .previewDistanceMeters
              .toString()
          : ConditionTransition.defaultPreviewDistanceMeters.toString(),
    );
    _conditionFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _conditionController.dispose();
    _previewDistanceController.dispose();
    _conditionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.allowDelete ? 'Edit Branch' : 'Create Branch'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.chooseWaypointKind) ...[
              DropdownButtonFormField<_WaypointKind>(
                key: const ValueKey('newConnectedWaypointType'),
                initialValue: _waypointKind,
                decoration:
                    const InputDecoration(labelText: 'New waypoint type'),
                items: const [
                  DropdownMenuItem(
                    value: _WaypointKind.translation,
                    child: Text('Translation waypoint'),
                  ),
                  DropdownMenuItem(
                    value: _WaypointKind.pose,
                    child: Text('Pose waypoint'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _waypointKind = value);
                  }
                },
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              key: const ValueKey('pathTransitionType'),
              initialValue: _transitionType,
              decoration: const InputDecoration(labelText: 'Transition'),
              items: const [
                DropdownMenuItem(
                  value: 'distance',
                  child: Text('Distance'),
                ),
                DropdownMenuItem(
                  value: 'condition',
                  child: Text('Condition'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _transitionType = value);
                }
              },
            ),
            const SizedBox(height: 14),
            if (_transitionType == 'distance')
              TextField(
                key: const ValueKey('pathTransitionDistance'),
                controller: _distanceController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Distance (m)',
                  errorText: _distanceError,
                  border: const OutlineInputBorder(),
                ),
              )
            else ...[
              RawAutocomplete<String>(
                textEditingController: _conditionController,
                focusNode: _conditionFocusNode,
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  return ProjectConditionRegistry.conditions.where(
                    (condition) =>
                        query.isEmpty ||
                        condition.toLowerCase().contains(query),
                  );
                },
                onSelected: (value) => _conditionController.text = value,
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onSubmitted,
                ) {
                  return TextField(
                    key: const ValueKey('pathTransitionCondition'),
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Condition (select or create)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSubmitted(),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: SizedBox(
                        width: 360,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            for (final option in options)
                              ListTile(
                                dense: true,
                                title: Text(option),
                                onTap: () => onSelected(option),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('pathConditionPreviewDistance'),
                controller: _previewDistanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Preview Distance (m)',
                  helperText:
                      'Used as the handoff distance while previewing this branch',
                  errorText: _previewDistanceError,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.allowDelete)
          TextButton.icon(
            key: const ValueKey('deletePathBranchButton'),
            onPressed: () => Navigator.of(context).pop(
              _PathTransitionDialogResult(
                transition: widget.initialTransition.clone(),
                delete: true,
              ),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('savePathTransitionButton'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    late final PathTransition transition;
    if (_transitionType == 'distance') {
      final value = num.tryParse(_distanceController.text);
      if (value == null || !value.isFinite || value < 0) {
        setState(() => _distanceError = 'Enter a non-negative number');
        return;
      }
      transition = DistanceTransition(distanceMeters: value);
    } else {
      final value = _conditionController.text.trim();
      final previewDistance = num.tryParse(_previewDistanceController.text);
      if (previewDistance == null ||
          !previewDistance.isFinite ||
          previewDistance < 0) {
        setState(
          () => _previewDistanceError = 'Enter a non-negative number',
        );
        return;
      }
      transition = ConditionTransition(
        conditionName: value.isEmpty ? null : value,
        previewDistanceMeters: previewDistance,
      );
      ProjectConditionRegistry.register(value);
    }
    Navigator.of(context).pop(
      _PathTransitionDialogResult(
        transition: transition,
        waypointKind: widget.chooseWaypointKind ? _waypointKind : null,
      ),
    );
  }
}
