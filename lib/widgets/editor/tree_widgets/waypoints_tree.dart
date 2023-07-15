import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
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

  const WaypointsTree({
    super.key,
    required this.path,
    this.onWaypointHovered,
    this.onWaypointSelected,
    this.onPathChanged,
    this.controller,
    this.initialSelectedWaypoint,
    this.onWaypointDeleted,
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
      initiallyExpanded: true,
      elevation: 1.0,
      children: [
        for (int w = 0; w < waypoints.length; w++) _buildWaypointTreeNode(w),
      ],
    );
  }

  void _setSelectedWaypoint(int? waypointIdx) {
    _ignoreExpansionFromTile = true;

    if (_selectedWaypoint != null) {
      _controllers[_selectedWaypoint!].collapse();
    }
    _selectedWaypoint = waypointIdx;
    _controllers[waypointIdx!].expand();
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
                setState(() {
                  waypoint.isLocked = !waypoint.isLocked;
                });
                widget.path.generateAndSavePath();
              },
              icon: Icon(waypoint.isLocked ? Icons.lock : Icons.lock_open,
                  color: colorScheme.onSurface),
            ),
          ),
          IconButton(
            onPressed: () => widget.onWaypointDeleted?.call(waypointIdx),
            icon: const Icon(Icons.delete_forever),
            color: colorScheme.error,
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
                      UndoRedo.addChange(_waypointChange(
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
                      UndoRedo.addChange(_waypointChange(
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
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      UndoRedo.addChange(_waypointChange(
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
        if (waypointIdx == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: NumberTextField(
                      initialText:
                          waypoint.getNextControlLength().toStringAsFixed(2),
                      label: 'Next Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
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
        if (waypointIdx == waypoints.length - 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: NumberTextField(
                      initialText:
                          waypoint.getPrevControlLength().toStringAsFixed(2),
                      label: 'Previous Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
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
              ],
            ),
          ),
        if (waypointIdx != 0 && waypointIdx != waypoints.length - 1)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: NumberTextField(
                      initialText:
                          waypoint.getPrevControlLength().toStringAsFixed(2),
                      label: 'Previous Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
                            wRef,
                            () => wRef.setPrevControlLength(value),
                            (oldVal) => wRef.setPrevControlLength(
                                oldVal.getPrevControlLength()),
                          ));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NumberTextField(
                      initialText:
                          waypoint.getNextControlLength().toStringAsFixed(2),
                      label: 'Next Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          UndoRedo.addChange(_waypointChange(
                            wRef,
                            () => wRef.setNextControlLength(value),
                            (oldVal) => wRef.setNextControlLength(
                                oldVal.getNextControlLength()),
                          ));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add),
              label: const Text('Insert New Waypoint'),
            ),
          ),
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
