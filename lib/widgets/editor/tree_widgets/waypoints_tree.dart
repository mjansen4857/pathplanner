import 'package:flutter/material.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class WaypointsTree extends StatefulWidget {
  final PathPlannerPath path;
  final ValueChanged<int?>? onWaypointHovered;
  final ValueChanged<int?>? onWaypointSelected;
  final ValueChanged<int>? onWaypointDeleted;
  final VoidCallback? onPathChanged;
  final WaypointsTreeController? controller;
  final int? initialSelectedWaypoint;
  final ChangeStack undoStack;
  final bool holonomicMode;

  const WaypointsTree({
    super.key,
    required this.path,
    this.onWaypointHovered,
    this.onWaypointSelected,
    this.onPathChanged,
    this.controller,
    this.initialSelectedWaypoint,
    this.onWaypointDeleted,
    required this.undoStack,
    this.holonomicMode = Defaults.holonomicMode,
  });

  @override
  State<WaypointsTree> createState() => _WaypointsTreeState();
}

class _WaypointsTreeState extends State<WaypointsTree> {
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedWaypoint;
  late WaypointsTreeController _treeController;
  bool _ignoreExpansionFromTile = false;
  final ExpansionTileController _expansionController =
      ExpansionTileController();

  @override
  void initState() {
    super.initState();

    _selectedWaypoint = widget.initialSelectedWaypoint;

    _controllers =
        List.generate(waypoints.length, (index) => ExpansionTileController());

    _treeController = widget.controller ?? WaypointsTreeController();
    _treeController._state = this;
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Waypoints'),
      trailing: ItemCount(count: widget.path.waypoints.length),
      initiallyExpanded: widget.path.waypointsExpanded,
      controller: _expansionController,
      onExpansionChanged: (value) {
        if (value != null) {
          widget.path.waypointsExpanded = value;
          if (value == false) {
            _selectedWaypoint = null;
            widget.onWaypointSelected?.call(null);
          }
        }
      },
      elevation: 1.0,
      children: [
        for (int w = 0; w < waypoints.length; w++) _buildWaypointTreeNode(w),
      ],
    );
  }

  void _setSelectedWaypoint(int? waypointIdx) {
    _ignoreExpansionFromTile = true;

    if (_selectedWaypoint != null && widget.path.waypointsExpanded) {
      _controllers[_selectedWaypoint!].collapse();
    }
    _selectedWaypoint = waypointIdx;
    if (waypointIdx != null && widget.path.waypointsExpanded) {
      _controllers[waypointIdx].expand();
    }
    _ignoreExpansionFromTile = false;
  }

  Widget _buildWaypointTreeNode(int waypointIdx) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    String name = 'Waypoint $waypointIdx';
    if (waypointIdx == 0) {
      name = 'Start Point';
    } else if (waypointIdx == waypoints.length - 1) {
      name = 'End Point';
    }

    Waypoint waypoint = waypoints[waypointIdx];

    return TreeCardNode(
      onHoverStart: () => widget.onWaypointHovered?.call(waypointIdx),
      onHoverEnd: () => widget.onWaypointHovered?.call(null),
      elevation: 4.0,
      controller: _controllers[waypointIdx],
      initiallyExpanded: waypointIdx == _selectedWaypoint,
      onExpansionChanged: (expanded) {
        if (!_ignoreExpansionFromTile) {
          if (expanded ?? false) {
            if (_selectedWaypoint != null) {
              _controllers[_selectedWaypoint!].collapse();
            }
            _selectedWaypoint = waypointIdx;
            widget.onWaypointSelected?.call(waypointIdx);
          } else {
            if (waypointIdx == _selectedWaypoint) {
              _selectedWaypoint = null;
              widget.onWaypointSelected?.call(null);
            }
          }
        }
      },
      title: Row(
        children: [
          Text(name),
          Expanded(child: Container()),
          Tooltip(
            message: waypoint.isLocked ? 'Unlock' : 'Lock',
            waitDuration: const Duration(seconds: 1),
            child: IconButton(
              onPressed: () {
                waypoint.isLocked = !waypoint.isLocked;
                widget.onPathChanged?.call();
              },
              icon: Icon(waypoint.isLocked ? Icons.lock : Icons.lock_open,
                  color: colorScheme.onSurface),
            ),
          ),
          if (waypoints.length > 2)
            Tooltip(
              message: 'Delete Waypoint',
              waitDuration: const Duration(seconds: 1),
              child: IconButton(
                onPressed: () => widget.onWaypointDeleted?.call(waypointIdx),
                icon: const Icon(Icons.delete_forever),
                color: colorScheme.error,
              ),
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialText: waypoint.anchor.x.toStringAsFixed(2),
                  label: 'X Position (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      widget.undoStack.add(_waypointChange(
                        wRef,
                        () => wRef.move(value, wRef.anchor.y),
                        (oldVal) => wRef.move(oldVal.anchor.x, oldVal.anchor.y),
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: waypoint.anchor.y.toStringAsFixed(2),
                  label: 'Y Position (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      widget.undoStack.add(_waypointChange(
                        wRef,
                        () => wRef.move(wRef.anchor.x, value),
                        (oldVal) => wRef.move(oldVal.anchor.x, oldVal.anchor.y),
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: waypoint.getHeadingDegrees().toStringAsFixed(2),
                  label: 'Heading (Deg)',
                  arrowKeyIncrement: 1.0,
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      widget.undoStack.add(_waypointChange(
                        wRef,
                        () => wRef.setHeading(value),
                        (oldVal) => wRef.setHeading(oldVal.getHeadingDegrees()),
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              if (waypointIdx != 0)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: NumberTextField(
                      initialText:
                          waypoint.getPrevControlLength().toStringAsFixed(2),
                      label: 'Previous Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null && value >= 0.05) {
                          Waypoint wRef = waypoints[waypointIdx];
                          widget.undoStack.add(_waypointChange(
                            wRef,
                            () => wRef.setPrevControlLength(value),
                            (oldVal) => wRef.setPrevControlLength(
                                oldVal.getPrevControlLength()),
                          ));
                        }
                      },
                    ),
                  ),
                ),
              if (waypointIdx != 0) const SizedBox(width: 8),
              if (waypointIdx != waypoints.length - 1)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: NumberTextField(
                      initialText:
                          waypoint.getNextControlLength().toStringAsFixed(2),
                      label: 'Next Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null && value >= 0.05) {
                          Waypoint wRef = waypoints[waypointIdx];
                          widget.undoStack.add(_waypointChange(
                            wRef,
                            () => wRef.setNextControlLength(value),
                            (oldVal) => wRef.setNextControlLength(
                                oldVal.getNextControlLength()),
                          ));
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.holonomicMode || waypointIdx != waypoints.length - 1)
          const SizedBox(height: 8.0),
        if (widget.holonomicMode || waypointIdx != waypoints.length - 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.holonomicMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.undoStack.add(Change(
                        PathPlannerPath.cloneRotationTargets(
                            widget.path.rotationTargets),
                        () {
                          widget.path.rotationTargets.add(
                              RotationTarget(waypointRelativePos: waypointIdx));
                          widget.onPathChanged?.call();
                        },
                        (oldValue) {
                          widget.path.rotationTargets =
                              PathPlannerPath.cloneRotationTargets(oldValue);
                          widget.onPathChanged?.call();
                        },
                      ));
                    },
                    icon: const Icon(Icons.replay, size: 20),
                    style: ElevatedButton.styleFrom(
                      elevation: 1.0,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    label: const Text('Add Rotation Target'),
                  ),
                ),
              if (waypointIdx != waypoints.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.undoStack.add(Change(
                        [
                          PathPlannerPath.cloneWaypoints(widget.path.waypoints),
                          PathPlannerPath.cloneConstraintZones(
                              widget.path.constraintZones),
                          PathPlannerPath.cloneEventMarkers(
                              widget.path.eventMarkers),
                          PathPlannerPath.cloneRotationTargets(
                              widget.path.rotationTargets),
                        ],
                        () {
                          widget.path.insertWaypointAfter(waypointIdx);
                          widget.onPathChanged?.call();
                        },
                        (oldValue) {
                          _selectedWaypoint = null;
                          widget.onWaypointHovered?.call(null);
                          widget.onWaypointSelected?.call(null);

                          widget.path.waypoints =
                              PathPlannerPath.cloneWaypoints(
                                  oldValue[0] as List<Waypoint>);
                          widget.path.constraintZones =
                              PathPlannerPath.cloneConstraintZones(
                                  oldValue[1] as List<ConstraintsZone>);
                          widget.path.eventMarkers =
                              PathPlannerPath.cloneEventMarkers(
                                  oldValue[2] as List<EventMarker>);
                          widget.path.rotationTargets =
                              PathPlannerPath.cloneRotationTargets(
                                  oldValue[3] as List<RotationTarget>);

                          widget.onPathChanged?.call();
                        },
                      ));
                    },
                    icon: const Icon(Icons.add, size: 20),
                    style: ElevatedButton.styleFrom(
                      elevation: 1.0,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    label: const Text('New Waypoint After'),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Change _waypointChange(
      Waypoint waypoint, VoidCallback execute, Function(Waypoint oldVal) undo) {
    return Change(
      waypoint.clone(),
      () {
        setState(() {
          execute.call();
          widget.onPathChanged?.call();
        });
      },
      (oldVal) {
        setState(() {
          undo.call(oldVal);
          widget.onPathChanged?.call();
        });
      },
    );
  }
}

class WaypointsTreeController {
  WaypointsTreeController();

  _WaypointsTreeState? _state;

  void setSelectedWaypoint(int? waypointIdx) {
    assert(_state != null);
    _state!._setSelectedWaypoint(waypointIdx);
  }
}
