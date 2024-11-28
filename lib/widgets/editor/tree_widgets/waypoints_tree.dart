import 'package:flutter/material.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/event_marker.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/prefs.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
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
      leading: const Icon(Icons.location_on_rounded),
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

    Waypoint waypoint = waypoints[waypointIdx];

    String name = 'Waypoint $waypointIdx';
    if (waypoint.isStartPoint) {
      name = 'Start Point';
    } else if (waypoint.isEndPoint) {
      name = 'End Point';
    }

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
          if (waypointIdx == 0)
            const Icon(Icons.start_rounded)
          else if (waypointIdx == waypoints.length - 1)
            const Icon(Icons.flag_outlined)
          else
            const Icon(Icons.room),
          const SizedBox(width: 8),
          Text(name),
          if (waypoint.linkedName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                message: waypoint.linkedName,
                child: const Icon(
                  Icons.link,
                  color: Colors.green,
                ),
              ),
            ),
          Expanded(child: Container()),
          Tooltip(
            message: waypoint.isLocked ? 'Unlock' : 'Lock',
            waitDuration: const Duration(seconds: 1),
            child: IconButton(
              onPressed: () {
                setState(() {
                  waypoint.isLocked = !waypoint.isLocked;
                });
                widget.onPathChanged?.call();
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  waypoint.isLocked
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  key: ValueKey<bool>(waypoint.isLocked),
                  color: waypoint.isLocked
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                  initialValue: waypoint.anchor.x,
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
                  initialValue: waypoint.anchor.y,
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
                  initialValue: waypoint.heading.degrees,
                  label: 'Heading (Deg)',
                  arrowKeyIncrement: 1.0,
                  onSubmitted: (value) {
                    if (value != null) {
                      Waypoint wRef = waypoints[waypointIdx];
                      widget.undoStack.add(_waypointChange(
                        wRef,
                        () => wRef.setHeading(Rotation2d.fromDegrees(value)),
                        (oldVal) => wRef.setHeading(oldVal.heading),
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
              if (!waypoint.isStartPoint)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: NumberTextField(
                      initialValue: waypoint.prevControlLength!,
                      label: 'Previous Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          widget.undoStack.add(_waypointChange(
                            wRef,
                            () => wRef.setPrevControlLength(value),
                            (oldVal) => wRef.setPrevControlLength(
                                oldVal.prevControlLength!),
                          ));
                        }
                      },
                    ),
                  ),
                ),
              if (!waypoint.isStartPoint && !waypoint.isEndPoint)
                const SizedBox(width: 8),
              if (!waypoint.isEndPoint)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: NumberTextField(
                      initialValue: waypoint.nextControlLength!,
                      label: 'Next Control Length (M)',
                      onSubmitted: (value) {
                        if (value != null) {
                          Waypoint wRef = waypoints[waypointIdx];
                          widget.undoStack.add(_waypointChange(
                            wRef,
                            () => wRef.setNextControlLength(value),
                            (oldVal) => wRef.setNextControlLength(
                                oldVal.nextControlLength!),
                          ));
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Center(
          child: Wrap(
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: [
              if (widget.holonomicMode)
                Tooltip(
                  message: 'Add Rotation Target at Waypoint',
                  child: IconButton(
                    onPressed: () {
                      widget.undoStack.add(Change(
                        PathPlannerPath.cloneRotationTargets(
                            widget.path.rotationTargets),
                        () {
                          widget.path.rotationTargets.add(
                              RotationTarget(waypointIdx, const Rotation2d()));
                          widget.onPathChanged?.call();
                        },
                        (oldValue) {
                          widget.path.rotationTargets =
                              PathPlannerPath.cloneRotationTargets(oldValue);
                          widget.onPathChanged?.call();
                        },
                      ));
                    },
                    icon: const Icon(Icons.rotate_right_rounded, size: 20),
                  ),
                ),
              if (waypointIdx != waypoints.length - 1)
                Tooltip(
                  message: 'Create New Waypoint After',
                  child: IconButton(
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
                  ),
                ),
              if (waypoint.linkedName == null)
                Tooltip(
                  message: 'Link Waypoint',
                  child: IconButton(
                    onPressed: () => _showLinkedDialog(waypointIdx),
                    icon: const Icon(Icons.add_link_rounded, size: 20),
                  ),
                ),
              if (waypoint.linkedName != null)
                Tooltip(
                  message: 'Unlink Waypoint',
                  child: IconButton(
                    onPressed: () {
                      widget.undoStack.add(_waypointChange(waypoint, () {
                        waypoint.linkedName = null;
                      }, (oldVal) {
                        waypoint.linkedName = oldVal.linkedName;
                      }));
                    },
                    icon: const Icon(Icons.link_off, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLinkedDialog(int waypointIdx) {
    final TextEditingController controller = TextEditingController();

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Link Waypoint'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Convert this waypoint to a linked waypoint. Updating the position one instance of a linked waypoint will update all linked waypoints under the same name.'),
                  const SizedBox(height: 18),
                  const Text(
                      'If you choose the name of an existing linked waypoint, this waypoint will be updated to match its position.'),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownMenu<String>(
                          label: const Text('Linked Waypoint Name'),
                          controller: controller,
                          enableSearch: false,
                          enableFilter: true,
                          width: 400,
                          dropdownMenuEntries: [
                            for (String name in Waypoint.linked.keys)
                              DropdownMenuEntry(
                                value: name,
                                label: name,
                              ),
                          ],
                          inputDecorationTheme: InputDecorationTheme(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 0),
                            isDense: true,
                            constraints: const BoxConstraints(
                              maxHeight: 42,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    String name = controller.text;

                    if (Waypoint.linked.containsKey(name)) {
                      // Linked waypoint exists, update this waypoint
                      Translation2d anchor = Waypoint.linked[name]!;

                      widget.undoStack
                          .add(_waypointChange(waypoints[waypointIdx], () {
                        waypoints[waypointIdx].linkedName = name;
                        waypoints[waypointIdx].move(anchor.x, anchor.y);
                      }, (oldVal) {
                        waypoints[waypointIdx] = oldVal.clone();
                      }));
                    } else {
                      // Create new linked waypoint
                      widget.undoStack
                          .add(_waypointChange(waypoints[waypointIdx], () {
                        waypoints[waypointIdx].linkedName = name;
                        Waypoint.linked[name] = waypoints[waypointIdx].anchor;
                      }, (oldVal) {
                        waypoints[waypointIdx] = oldVal.clone();
                        Waypoint.linked.remove(name);
                      }));
                    }
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        });
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
