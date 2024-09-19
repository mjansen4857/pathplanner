import 'package:flutter/material.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/constraint_zones_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/editor_settings_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/event_markers_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/global_constraints_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/goal_end_state_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/rotation_targets_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:undo/undo.dart';

class PathTree extends StatefulWidget {
  final PathPlannerPath path;
  final ValueChanged<int?>? onWaypointHovered;
  final ValueChanged<int?>? onWaypointSelected;
  final ValueChanged<int?>? onZoneHovered;
  final ValueChanged<int?>? onZoneSelected;
  final ValueChanged<int?>? onRotTargetHovered;
  final ValueChanged<int?>? onRotTargetSelected;
  final ValueChanged<int?>? onMarkerHovered;
  final ValueChanged<int?>? onMarkerSelected;
  final ValueChanged<int>? onWaypointDeleted;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onPathChanged;
  final VoidCallback? onPathChangedNoSim;
  final WaypointsTreeController? waypointsTreeController;
  final int? initiallySelectedWaypoint;
  final int? initiallySelectedZone;
  final int? initiallySelectedRotTarget;
  final int? initiallySelectedMarker;
  final ChangeStack undoStack;
  final Widget? runtimeDisplay;
  final bool holonomicMode;
  final PathConstraints defaultConstraints;

  const PathTree({
    super.key,
    required this.path,
    this.onWaypointHovered,
    this.onSideSwapped,
    this.onPathChanged,
    this.onWaypointSelected,
    this.waypointsTreeController,
    this.initiallySelectedWaypoint,
    this.onWaypointDeleted,
    this.onZoneHovered,
    this.onZoneSelected,
    this.initiallySelectedZone,
    this.onRotTargetHovered,
    this.onRotTargetSelected,
    this.initiallySelectedRotTarget,
    this.onMarkerHovered,
    this.onMarkerSelected,
    this.initiallySelectedMarker,
    required this.undoStack,
    this.runtimeDisplay,
    this.onPathChangedNoSim,
    required this.holonomicMode,
    required this.defaultConstraints,
  });

  @override
  State<PathTree> createState() => _PathTreeState();
}

class _PathTreeState extends State<PathTree> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 4.0),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildWaypointsTree(),
                _buildEventMarkersTree(),
                if (widget.holonomicMode) _buildRotationTargetsTree(),
                const Divider(),
                _buildGoalEndStateTree(),
                _buildGlobalConstraintsTree(),
                _buildConstraintZonesTree(),
                const Divider(),
                const EditorSettingsTree(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Container()),
          if (!widget.holonomicMode) ...[
            _buildReversedButton(),
            const SizedBox(width: 8),
            Tooltip(
              message:
                  'Moving ${widget.path.reversed ? 'Reversed' : 'Forward'}',
              child: _buildInfoCard(
                value: widget.path.reversed ? 'RVD' : 'FWD',
              ),
            ),
          ],
          const SizedBox(width: 16),
          if (widget.runtimeDisplay != null) widget.runtimeDisplay!,
          const SizedBox(width: 16),
          Tooltip(
            message: 'Move to Other Side',
            waitDuration: const Duration(seconds: 1),
            child: IconButton(
              onPressed: widget.onSideSwapped,
              icon: const Icon(Icons.swap_horiz),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(36, 0, 0, 0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.normal,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildWaypointsTree() {
    return WaypointsTree(
      key: ValueKey('waypoints${widget.path.waypoints.length}'),
      onWaypointDeleted: widget.onWaypointDeleted,
      initialSelectedWaypoint: widget.initiallySelectedWaypoint,
      controller: widget.waypointsTreeController,
      path: widget.path,
      onWaypointHovered: widget.onWaypointHovered,
      onWaypointSelected: widget.onWaypointSelected,
      onPathChanged: widget.onPathChanged,
      undoStack: widget.undoStack,
      holonomicMode: widget.holonomicMode,
    );
  }

  Widget _buildGlobalConstraintsTree() {
    return GlobalConstraintsTree(
      path: widget.path,
      onPathChanged: widget.onPathChanged,
      undoStack: widget.undoStack,
      defaultConstraints: widget.defaultConstraints,
    );
  }

  Widget _buildGoalEndStateTree() {
    return GoalEndStateTree(
      path: widget.path,
      onPathChanged: widget.onPathChanged,
      undoStack: widget.undoStack,
      holonomicMode: widget.holonomicMode,
    );
  }

  Widget _buildRotationTargetsTree() {
    return RotationTargetsTree(
      key: ValueKey('rotations${widget.path.rotationTargets.length}'),
      path: widget.path,
      onPathChanged: widget.onPathChanged,
      onPathChangedNoSim: widget.onPathChangedNoSim,
      onTargetHovered: widget.onRotTargetHovered,
      onTargetSelected: widget.onRotTargetSelected,
      initiallySelectedTarget: widget.initiallySelectedRotTarget,
      undoStack: widget.undoStack,
    );
  }

  Widget _buildEventMarkersTree() {
    return EventMarkersTree(
      key: ValueKey('markers${widget.path.eventMarkers.length}'),
      path: widget.path,
      onPathChangedNoSim: widget.onPathChangedNoSim,
      onMarkerHovered: widget.onMarkerHovered,
      onMarkerSelected: widget.onMarkerSelected,
      initiallySelectedMarker: widget.initiallySelectedMarker,
      undoStack: widget.undoStack,
    );
  }

  Widget _buildConstraintZonesTree() {
    return ConstraintZonesTree(
      key: ValueKey('zones${widget.path.constraintZones.length}'),
      path: widget.path,
      onPathChanged: widget.onPathChanged,
      onPathChangedNoSim: widget.onPathChangedNoSim,
      onZoneHovered: widget.onZoneHovered,
      onZoneSelected: widget.onZoneSelected,
      initiallySelectedZone: widget.initiallySelectedZone,
      undoStack: widget.undoStack,
    );
  }

  Widget _buildReversedButton() {
    return Tooltip(
      message: widget.path.reversed ? 'Unreverse Path' : 'Reverse Path',
      child: GestureDetector(
        onTap: () {
          bool newReversed = !widget.path.reversed;

          widget.undoStack.add(Change(
            widget.path.reversed,
            () {
              widget.path.reversed = newReversed;
              widget.onPathChanged?.call();
            },
            (oldValue) {
              widget.path.reversed = oldValue;
              widget.onPathChanged?.call();
            },
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(36, 0, 0, 0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.path.reversed
                ? Icons.arrow_forward_rounded
                : Icons.arrow_back_rounded,
            color: Colors.white,
            size: 15,
          ),
        ),
      ),
    );
  }
}
