import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/constraint_zones_tree.dart';
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
  final num? pathRuntime;
  final bool holonomicMode;

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
    this.pathRuntime,
    this.onPathChangedNoSim,
    required this.holonomicMode,
  });

  @override
  State<PathTree> createState() => _PathTreeState();
}

class _PathTreeState extends State<PathTree> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Text(
                'Simulated Driving Time: ~${(widget.pathRuntime ?? 0).toStringAsFixed(2)}s',
                style: const TextStyle(fontSize: 18),
              ),
              Expanded(child: Container()),
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
        ),
        const SizedBox(height: 4.0),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                WaypointsTree(
                  key: ValueKey('waypoints${widget.path.waypoints.length}'),
                  onWaypointDeleted: widget.onWaypointDeleted,
                  initialSelectedWaypoint: widget.initiallySelectedWaypoint,
                  controller: widget.waypointsTreeController,
                  path: widget.path,
                  onWaypointHovered: widget.onWaypointHovered,
                  onWaypointSelected: widget.onWaypointSelected,
                  onPathChanged: widget.onPathChanged,
                  undoStack: widget.undoStack,
                ),
                GlobalConstraintsTree(
                  path: widget.path,
                  onPathChanged: widget.onPathChanged,
                  undoStack: widget.undoStack,
                ),
                GoalEndStateTree(
                  path: widget.path,
                  onPathChanged: widget.onPathChanged,
                  undoStack: widget.undoStack,
                  holonomicMode: widget.holonomicMode,
                ),
                if (widget.holonomicMode)
                  RotationTargetsTree(
                    key: ValueKey(
                        'rotations${widget.path.rotationTargets.length}'),
                    path: widget.path,
                    onPathChanged: widget.onPathChanged,
                    onPathChangedNoSim: widget.onPathChangedNoSim,
                    onTargetHovered: widget.onRotTargetHovered,
                    onTargetSelected: widget.onRotTargetSelected,
                    initiallySelectedTarget: widget.initiallySelectedRotTarget,
                    undoStack: widget.undoStack,
                  ),
                EventMarkersTree(
                  key: ValueKey('markers${widget.path.eventMarkers.length}'),
                  path: widget.path,
                  onPathChangedNoSim: widget.onPathChangedNoSim,
                  onMarkerHovered: widget.onMarkerHovered,
                  onMarkerSelected: widget.onMarkerSelected,
                  initiallySelectedMarker: widget.initiallySelectedMarker,
                  undoStack: widget.undoStack,
                ),
                ConstraintZonesTree(
                  key: ValueKey('zones${widget.path.constraintZones.length}'),
                  path: widget.path,
                  onPathChanged: widget.onPathChanged,
                  onPathChangedNoSim: widget.onPathChangedNoSim,
                  onZoneHovered: widget.onZoneHovered,
                  onZoneSelected: widget.onZoneSelected,
                  initiallySelectedZone: widget.initiallySelectedZone,
                  undoStack: widget.undoStack,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
