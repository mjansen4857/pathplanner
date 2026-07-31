import 'package:flutter/material.dart';
import 'package:pathplanner/path2/graph.dart';
import 'package:pathplanner/path2/pathplanner_auto.dart';
import 'package:pathplanner/services/project_condition_registry.dart';
import 'package:pathplanner/widgets/editor/graph_editor/visual_graph_editor.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path2_starting_pose_tree.dart';
import 'package:undo/undo.dart';

/// Visual directed-graph editor for Path 2 autos.
class Path2AutoTree extends StatefulWidget {
  final Path2Auto auto;
  final List<String> allPathNames;
  final ValueChanged<String?>? onNodeHovered;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onAutoChanged;
  final ChangeStack undoStack;
  final ValueChanged<String?>? onEditPathPressed;

  const Path2AutoTree({
    super.key,
    required this.auto,
    required this.allPathNames,
    required this.undoStack,
    this.onNodeHovered,
    this.onSideSwapped,
    this.onAutoChanged,
    this.onEditPathPressed,
  });

  @override
  State<Path2AutoTree> createState() => _Path2AutoTreeState();
}

class _Path2AutoTreeState extends State<Path2AutoTree> {
  static const Size _nodeSize = Size(300, 190);

  final VisualGraphController _graphController = VisualGraphController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningMessages = _warningMessages();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              FilledButton.icon(
                key: const ValueKey('path2AutoAddPathNode'),
                onPressed: widget.allPathNames.isEmpty ? null : _addToolbarNode,
                icon: const Icon(Icons.add),
                label: const Text('Add Path'),
              ),
              const SizedBox(width: 8),
              if (warningMessages.isNotEmpty)
                Tooltip(
                  message: warningMessages.join('\n'),
                  child: Semantics(
                    label: warningMessages.join('. '),
                    child: Row(
                      key: const ValueKey('path2AutoGraphWarnings'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${warningMessages.length} '
                          '${warningMessages.length == 1 ? 'warning' : 'warnings'}',
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Move to Other Side',
                onPressed: widget.onSideSwapped,
                icon: const Icon(Icons.swap_horiz),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Path2StartingPoseTree(
          auto: widget.auto,
          undoStack: widget.undoStack,
          onAutoChanged: widget.onAutoChanged,
          initiallyExpanded: true,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: colorScheme.surfaceContainerLowest,
              child: Stack(
                children: [
                  VisualGraphEditor(
                    controller: _graphController,
                    nodes: [
                      for (final node in widget.auto.nodes)
                        VisualGraphNode(
                          id: node.id,
                          position: node.editorPosition,
                          size: _nodeSize,
                          child: _buildNodeCard(node),
                        ),
                    ],
                    branches: [
                      for (final branch in widget.auto.branches)
                        VisualGraphBranch(
                          id: branch.id,
                          sourceId: branch.sourceId,
                          targetId: branch.targetId,
                          badge: _buildBranchBadge(branch),
                          color: _branchColor(branch),
                        ),
                    ],
                    onNodeMoved: _moveNode,
                    onConnect: _connectNodes,
                    onConnectToEmpty: _connectToNewNode,
                    onBranchTap: _editBranch,
                  ),
                  if (widget.auto.nodes.isEmpty)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            'Add a path node to begin this auto',
                            key: ValueKey('path2AutoEmptyGraph'),
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
    );
  }

  Widget _buildNodeCard(AutoNode node) {
    return switch (node) {
      PathAutoNode() => _buildPathNodeCard(node),
    };
  }

  Widget _buildPathNodeCard(PathAutoNode pathNode) {
    final colorScheme = Theme.of(context).colorScheme;
    final incoming = widget.auto.branches
        .where((branch) => branch.targetId == pathNode.id)
        .length;
    final outgoing = widget.auto.branches
        .where((branch) => branch.sourceId == pathNode.id)
        .length;
    final pathMissing = pathNode.pathName == null ||
        !widget.allPathNames.contains(pathNode.pathName);
    final selectableNames = widget.allPathNames.toSet().toList()..sort();
    if (pathNode.pathName != null &&
        !selectableNames.contains(pathNode.pathName)) {
      selectableNames.insert(0, pathNode.pathName!);
    }

    return MouseRegion(
      key: ValueKey('path2AutoNode-${pathNode.id}'),
      onEnter: (_) => widget.onNodeHovered?.call(pathNode.id),
      onExit: (_) => widget.onNodeHovered?.call(null),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: (_nodeSize.width - 28) / 2,
            child: GraphConnectorHandle(
              nodeId: pathNode.id,
              side: GraphConnectorSide.top,
            ),
          ),
          Positioned.fill(
            top: 10,
            bottom: 10,
            child: Card(
              margin: const EdgeInsets.all(4),
              elevation: 4,
              color: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GraphNodeDragHandle(
                    nodeId: pathNode.id,
                    child: ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Icon(Icons.route_rounded, size: 19),
                            SizedBox(width: 8),
                            Text(
                              'Path',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Spacer(),
                            Icon(Icons.drag_indicator_rounded, size: 19),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            key: ValueKey(
                              'path2AutoNodePath-${pathNode.id}',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Path',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: pathNode.pathName,
                                isExpanded: true,
                                isDense: true,
                                hint: const Text('Select path'),
                                items: [
                                  for (final pathName in selectableNames)
                                    DropdownMenuItem(
                                      value: pathName,
                                      child: Text(
                                        widget.allPathNames.contains(pathName)
                                            ? pathName
                                            : '$pathName (missing)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (pathName) =>
                                    _setNodePath(pathNode.id, pathName),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Open Path',
                          onPressed: pathMissing
                              ? null
                              : () => widget.onEditPathPressed
                                  ?.call(pathNode.pathName),
                          icon: const Icon(Icons.open_in_new_rounded),
                        ),
                        IconButton(
                          key: ValueKey(
                            'path2AutoDeleteNode-${pathNode.id}',
                          ),
                          tooltip: 'Delete Auto Node',
                          onPressed: () => _deleteNode(pathNode.id),
                          color: colorScheme.error,
                          icon: const Icon(Icons.delete_forever_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (incoming == 0)
                          const _TopologyBadge(
                            icon: Icons.start_rounded,
                            label: 'Start',
                          ),
                        if (outgoing == 0)
                          const _TopologyBadge(
                            icon: Icons.flag_outlined,
                            label: 'End',
                          ),
                        _TopologyBadge(
                          icon: Icons.call_received_rounded,
                          label: '$incoming in',
                        ),
                        _TopologyBadge(
                          icon: Icons.call_made_rounded,
                          label: '$outgoing out',
                        ),
                        if (pathMissing)
                          _TopologyBadge(
                            icon: Icons.warning_amber_rounded,
                            label: pathNode.pathName == null
                                ? 'Path unset'
                                : 'Missing path',
                            color: colorScheme.error,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: (_nodeSize.width - 28) / 2,
            child: GraphConnectorHandle(
              nodeId: pathNode.id,
              side: GraphConnectorSide.bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchBadge(AutoBranch branch) {
    final transition = branch.transition;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transition is FinishedTransition) ...[
          const Icon(Icons.check_rounded, size: 16),
          const SizedBox(width: 3),
          const Flexible(child: Text('Finished')),
        ] else if (transition is ConditionTransition) ...[
          Icon(
            Icons.question_mark_rounded,
            size: 16,
            color: transition.conditionName?.trim().isEmpty ?? true
                ? Theme.of(context).colorScheme.error
                : null,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              transition.conditionName?.trim().isNotEmpty ?? false
                  ? transition.conditionName!
                  : 'Unset',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Color? _branchColor(AutoBranch branch) {
    final transition = branch.transition;
    if (transition is ConditionTransition &&
        (transition.conditionName == null ||
            transition.conditionName!.trim().isEmpty)) {
      return Theme.of(context).colorScheme.error;
    }
    return null;
  }

  List<String> _warningMessages() {
    final messages = [...widget.auto.diagnostics.warnings];
    for (final node in widget.auto.nodes.whereType<PathAutoNode>()) {
      final pathName = node.pathName;
      if (pathName != null && !widget.allPathNames.contains(pathName)) {
        messages.add(
          'Auto node ${node.id} references missing path "$pathName"',
        );
      }
    }
    return messages;
  }

  Future<void> _addToolbarNode() async {
    final pathName = await _choosePath();
    if (!mounted || pathName == null) {
      return;
    }
    final viewportCenter =
        _graphController.viewportCenterInScene ?? const Offset(300, 220);
    final node = PathAutoNode(
      pathName: pathName,
      editorPosition: viewportCenter - _nodeSize.center(Offset.zero),
    );
    _performGraphChange(() => widget.auto.addNode(node.clone()));
  }

  Future<void> _connectNodes(GraphConnectionRequest request) async {
    if (!widget.auto.canAddBranch(request.sourceId, request.targetId)) {
      _showMessage('That connection would create a cycle');
      return;
    }
    final transition = await _chooseTransition(
      sourceId: request.sourceId,
    );
    if (!mounted || transition == null) {
      return;
    }
    if (!widget.auto.canAddBranch(
      request.sourceId,
      request.targetId,
      transition: transition,
    )) {
      _showMessage('That transition is not allowed from this node');
      return;
    }
    final branch = AutoBranch(
      sourceId: request.sourceId,
      targetId: request.targetId,
      transition: transition,
    );
    _performGraphChange(() => widget.auto.addBranch(branch.clone()));
  }

  Future<void> _connectToNewNode(
    GraphEmptyConnectionRequest request,
  ) async {
    final pathName = await _choosePath();
    if (!mounted || pathName == null) {
      return;
    }
    final node = PathAutoNode(
      pathName: pathName,
      editorPosition: request.scenePosition - _nodeSize.center(Offset.zero),
    );
    final sourceId = request.existingNodeIsSource ? request.nodeId : node.id;
    final targetId = request.existingNodeIsSource ? node.id : request.nodeId;
    final transition = await _chooseTransition(
      sourceId: sourceId,
      sourceIsNew: !request.existingNodeIsSource,
    );
    if (!mounted || transition == null) {
      return;
    }
    if (request.existingNodeIsSource &&
        transition is FinishedTransition &&
        _hasFinishedBranch(request.nodeId)) {
      _showMessage('This node already has a finished transition');
      return;
    }

    final branch = AutoBranch(
      sourceId: sourceId,
      targetId: targetId,
      transition: transition,
    );
    _performGraphChange(() {
      if (!widget.auto.addNode(node.clone())) {
        return;
      }
      if (!widget.auto.addBranch(branch.clone())) {
        widget.auto.removeNode(node.id);
      }
    });
  }

  Future<void> _editBranch(String branchId, Offset globalPosition) async {
    AutoBranch? branch;
    for (final candidate in widget.auto.branches) {
      if (candidate.id == branchId) {
        branch = candidate;
        break;
      }
    }
    if (branch == null) {
      return;
    }
    final result = await showDialog<_TransitionDialogResult>(
      context: context,
      anchorPoint: globalPosition,
      builder: (context) => _AutoTransitionDialog(
        initialTransition: branch!.transition,
        finishedEnabled: !_hasFinishedBranch(
          branch.sourceId,
          excludingBranchId: branch.id,
        ),
        allowDelete: true,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.delete) {
      _performGraphChange(() => widget.auto.removeBranch(branchId));
      return;
    }
    final transition = result.transition;
    if (transition == null) {
      return;
    }
    if (transition is FinishedTransition &&
        _hasFinishedBranch(
          branch.sourceId,
          excludingBranchId: branch.id,
        )) {
      _showMessage('This node already has a finished transition');
      return;
    }
    ProjectConditionRegistry.register(
      transition is ConditionTransition ? transition.conditionName : null,
    );
    _performGraphChange(() {
      for (final candidate in widget.auto.branches) {
        if (candidate.id == branchId) {
          candidate.transition = transition.clone();
          break;
        }
      }
    });
  }

  Future<String?> _choosePath() {
    final pathNames = widget.allPathNames.toSet().toList()..sort();
    if (pathNames.isEmpty) {
      return Future.value();
    }
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Path'),
        children: [
          for (final pathName in pathNames)
            SimpleDialogOption(
              key: ValueKey('path2AutoChoosePath-$pathName'),
              onPressed: () => Navigator.of(context).pop(pathName),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(pathName),
              ),
            ),
        ],
      ),
    );
  }

  Future<AutoTransition?> _chooseTransition({
    required String sourceId,
    bool sourceIsNew = false,
  }) async {
    final result = await showDialog<_TransitionDialogResult>(
      context: context,
      builder: (context) => _AutoTransitionDialog(
        initialTransition: const FinishedTransition(),
        finishedEnabled: sourceIsNew || !_hasFinishedBranch(sourceId),
      ),
    );
    return result?.transition;
  }

  bool _hasFinishedBranch(
    String sourceId, {
    String? excludingBranchId,
  }) {
    return widget.auto.branches.any(
      (branch) =>
          branch.id != excludingBranchId &&
          branch.sourceId == sourceId &&
          branch.transition is FinishedTransition,
    );
  }

  void _setNodePath(String nodeId, String? pathName) {
    final node = widget.auto.nodeById(nodeId);
    if (node is! PathAutoNode || node.pathName == pathName) {
      return;
    }
    _performGraphChange(() {
      final current = widget.auto.nodeById(nodeId);
      if (current is PathAutoNode) {
        current.pathName = pathName;
      }
    });
  }

  void _deleteNode(String nodeId) {
    _performGraphChange(() => widget.auto.removeNode(nodeId));
    if (widget.onNodeHovered != null) {
      widget.onNodeHovered!(null);
    }
  }

  void _moveNode(
    String nodeId,
    Offset oldPosition,
    Offset newPosition,
  ) {
    if (oldPosition == newPosition) {
      return;
    }
    _performGraphChange(() {
      widget.auto.nodeById(nodeId)?.editorPosition = newPosition;
    });
  }

  void _performGraphChange(VoidCallback execute) {
    final oldGraph = widget.auto.snapshotGraph();
    widget.undoStack.add(
      Change<AutoGraphSnapshot>(
        oldGraph,
        () {
          setState(execute);
          widget.onAutoChanged?.call();
        },
        (snapshot) {
          setState(() => widget.auto.restoreGraph(snapshot));
          widget.onAutoChanged?.call();
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TopologyBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _TopologyBadge({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: resolvedColor),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: resolvedColor),
        ),
      ],
    );
  }
}

class _TransitionDialogResult {
  final AutoTransition? transition;
  final bool delete;

  const _TransitionDialogResult.transition(this.transition) : delete = false;

  const _TransitionDialogResult.delete()
      : transition = null,
        delete = true;
}

enum _AutoTransitionKind { finished, condition }

class _AutoTransitionDialog extends StatefulWidget {
  final AutoTransition initialTransition;
  final bool finishedEnabled;
  final bool allowDelete;

  const _AutoTransitionDialog({
    required this.initialTransition,
    required this.finishedEnabled,
    this.allowDelete = false,
  });

  @override
  State<_AutoTransitionDialog> createState() => _AutoTransitionDialogState();
}

class _AutoTransitionDialogState extends State<_AutoTransitionDialog> {
  late _AutoTransitionKind _kind;
  TextEditingController? _conditionController;
  late final TextEditingController _previewDistanceController;
  String? _previewDistanceError;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialTransition is FinishedTransition
        ? _AutoTransitionKind.finished
        : _AutoTransitionKind.condition;
    if (_kind == _AutoTransitionKind.finished && !widget.finishedEnabled) {
      _kind = _AutoTransitionKind.condition;
    }
    _previewDistanceController = TextEditingController(
      text: widget.initialTransition is ConditionTransition
          ? (widget.initialTransition as ConditionTransition)
              .previewDistanceMeters
              .toString()
          : ConditionTransition.defaultPreviewDistanceMeters.toString(),
    );
  }

  @override
  void dispose() {
    _previewDistanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initialCondition = widget.initialTransition is ConditionTransition
        ? (widget.initialTransition as ConditionTransition).conditionName ?? ''
        : '';

    return AlertDialog(
      title: const Text('Branch Transition'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_AutoTransitionKind>(
              segments: [
                ButtonSegment(
                  value: _AutoTransitionKind.finished,
                  enabled: widget.finishedEnabled,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Finished'),
                ),
                const ButtonSegment(
                  value: _AutoTransitionKind.condition,
                  icon: Icon(Icons.question_mark_rounded),
                  label: Text('Condition'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) {
                setState(() => _kind = selection.single);
              },
            ),
            if (_kind == _AutoTransitionKind.condition) ...[
              const SizedBox(height: 16),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: initialCondition),
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  final conditions =
                      ProjectConditionRegistry.conditions.toList()..sort();
                  return conditions.where(
                    (condition) =>
                        query.isEmpty ||
                        condition.toLowerCase().contains(query),
                  );
                },
                onSelected: (condition) {
                  _conditionController?.text = condition;
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onSubmitted,
                ) {
                  _conditionController = controller;
                  return TextField(
                    key: const ValueKey('path2AutoConditionName'),
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Condition Name',
                      hintText: 'Select or create a condition',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _save(),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('path2AutoConditionPreviewDistance'),
                controller: _previewDistanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Preview Distance (m)',
                  helperText:
                      'Used as the handoff distance when previewing conditions',
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
            key: const ValueKey('path2AutoDeleteBranch'),
            onPressed: () => Navigator.of(context).pop(
              const _TransitionDialogResult.delete(),
            ),
            icon: Icon(Icons.delete_forever_rounded, color: colorScheme.error),
            label: Text(
              'Delete',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('path2AutoSaveTransition'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final previewDistance = num.tryParse(_previewDistanceController.text);
    if (_kind == _AutoTransitionKind.condition &&
        (previewDistance == null ||
            !previewDistance.isFinite ||
            previewDistance < 0)) {
      setState(
        () => _previewDistanceError = 'Enter a non-negative number',
      );
      return;
    }
    final transition = switch (_kind) {
      _AutoTransitionKind.finished => const FinishedTransition(),
      _AutoTransitionKind.condition => ConditionTransition(
          conditionName: _emptyToNull(_conditionController?.text),
          previewDistanceMeters: previewDistance!,
        ),
    };
    if (transition is ConditionTransition) {
      ProjectConditionRegistry.register(transition.conditionName);
    }
    Navigator.of(context).pop(
      _TransitionDialogResult.transition(transition),
    );
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
