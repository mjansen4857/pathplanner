import 'package:flutter/material.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/constraint_zones_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/editor_settings_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/event_markers_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/global_constraints_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/goal_end_state_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/ideal_starting_state_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/path_optimization_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/point_towards_zones_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/rotation_targets_tree.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/waypoints_tree.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undo/undo.dart';

class PathTree extends StatefulWidget {
  final PathPlannerPath path;
  final ValueChanged<int?>? onWaypointHovered;
  final ValueChanged<int?>? onWaypointSelected;
  final ValueChanged<int?>? onZoneHovered;
  final ValueChanged<int?>? onZoneSelected;
  final ValueChanged<int?>? onPointZoneHovered;
  final ValueChanged<int?>? onPointZoneSelected;
  final ValueChanged<int?>? onRotTargetHovered;
  final ValueChanged<int?>? onRotTargetSelected;
  final ValueChanged<int?>? onMarkerHovered;
  final ValueChanged<int?>? onMarkerSelected;
  final ValueChanged<int>? onWaypointDeleted;
  final ValueChanged<PathPlannerPath?>? onOptimizationUpdate;
  final VoidCallback? onSideSwapped;
  final VoidCallback? onPathChanged;
  final VoidCallback? onPathChangedNoSim;
  final WaypointsTreeController? waypointsTreeController;
  final int? initiallySelectedWaypoint;
  final int? initiallySelectedZone;
  final int? initiallySelectedPointZone;
  final int? initiallySelectedRotTarget;
  final int? initiallySelectedMarker;
  final ChangeStack undoStack;
  final num? pathRuntime;
  final bool holonomicMode;
  final PathConstraints defaultConstraints;
  final SharedPreferences prefs;
  final Widget? runtimeDisplay;
  final Size fieldSizeMeters;
  final VoidCallback? onRenderPath;

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
    this.onOptimizationUpdate,
    this.onZoneHovered,
    this.onZoneSelected,
    this.initiallySelectedZone,
    this.onPointZoneHovered,
    this.onPointZoneSelected,
    this.initiallySelectedPointZone,
    this.onRotTargetHovered,
    this.onRotTargetSelected,
    this.initiallySelectedRotTarget,
    this.onMarkerHovered,
    this.onMarkerSelected,
    this.initiallySelectedMarker,
    required this.undoStack,
    this.runtimeDisplay,
    this.pathRuntime,
    this.onPathChangedNoSim,
    required this.holonomicMode,
    required this.defaultConstraints,
    required this.prefs,
    required this.fieldSizeMeters,
    this.onRenderPath,
  });

  @override
  State<PathTree> createState() => _PathTreeState();
}

class _PathTreeState extends State<PathTree> {
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
                if (widget.holonomicMode) ...[
                  _buildRotationTargetsTree(),
                  _buildPointZonesTree(),
                ],
                const Divider(),
                _buildIdealStartingStateTree(),
                _buildGoalEndStateTree(),
                const Divider(),
                _buildGlobalConstraintsTree(),
                _buildConstraintZonesTree(),
                if (!widget.holonomicMode) _buildReversedCheckbox(),
                const Divider(),
                _buildPathOptimizationTree(),
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
          Row(
            children: [
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
                const SizedBox(width: 16),
              ],
              if (widget.runtimeDisplay != null) widget.runtimeDisplay!,
            ],
          ),
          Row(
            children: [
              Tooltip(
                message: 'Export Path to Image',
                waitDuration: const Duration(milliseconds: 500),
                child: IconButton(
                  onPressed: widget.onRenderPath,
                  icon: const Icon(Icons.ios_share),
                ),
              ),
              Tooltip(
                message: 'Move to Other Side',
                waitDuration: const Duration(milliseconds: 500),
                child: IconButton(
                  onPressed: widget.onSideSwapped,
                  icon: const Icon(Icons.swap_horiz),
                ),
              ),
            ],
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

  Widget _buildIdealStartingStateTree() {
    return IdealStartingStateTree(
      path: widget.path,
      undoStack: widget.undoStack,
      holonomicMode: widget.holonomicMode,
      onPathChanged: widget.onPathChanged,
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

  Widget _buildPointZonesTree() {
    return PointTowardsZonesTree(
      key: ValueKey('pointZones${widget.path.pointTowardsZones.length}'),
      path: widget.path,
      onPathChanged: widget.onPathChanged,
      onPathChangedNoSim: widget.onPathChangedNoSim,
      onZoneHovered: widget.onPointZoneHovered,
      onZoneSelected: widget.onPointZoneSelected,
      initiallySelectedZone: widget.initiallySelectedPointZone,
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

  Widget _buildReversedCheckbox() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1.0,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        child: Row(
          children: [
            Checkbox(
              value: widget.path.reversed,
              onChanged: (value) {
                bool reversed = value ?? false;

                widget.undoStack.add(Change(
                  widget.path.reversed,
                  () {
                    widget.path.reversed = reversed;
                    widget.onPathChanged?.call();
                  },
                  (oldValue) {
                    widget.path.reversed = oldValue;
                    widget.onPathChanged?.call();
                  },
                ));
              },
            ),
            const SizedBox(width: 4),
            const Text(
              'Reversed',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathOptimizationTree() {
    return PathOptimizationTree(
      path: widget.path,
      onPathChanged: widget.onPathChanged,
      onUpdate: widget.onOptimizationUpdate,
      undoStack: widget.undoStack,
      prefs: widget.prefs,
      fieldSizeMeters: widget.fieldSizeMeters,
    );
  }
}
