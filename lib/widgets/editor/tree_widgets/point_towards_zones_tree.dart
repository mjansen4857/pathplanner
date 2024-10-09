import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/point_towards_zone.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:undo/undo.dart';

class PointTowardsZonesTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final VoidCallback? onPathChangedNoSim;
  final ValueChanged<int?>? onZoneHovered;
  final ValueChanged<int?>? onZoneSelected;
  final int? initiallySelectedZone;
  final ChangeStack undoStack;

  const PointTowardsZonesTree({
    super.key,
    required this.path,
    this.onPathChanged,
    this.onPathChangedNoSim,
    this.onZoneHovered,
    this.onZoneSelected,
    this.initiallySelectedZone,
    required this.undoStack,
  });

  @override
  State<PointTowardsZonesTree> createState() => _PointTowardsZonesTreeState();
}

class _PointTowardsZonesTreeState extends State<PointTowardsZonesTree> {
  List<PointTowardsZone> get zones => widget.path.pointTowardsZones;
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedZone;

  double _sliderChangeStart = 0;

  @override
  void initState() {
    super.initState();

    _selectedZone = widget.initiallySelectedZone;

    _controllers =
        List.generate(zones.length, (index) => ExpansionTileController());
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Point Towards Zones'),
      leading: const Icon(Icons.rotate_left_rounded),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              widget.undoStack.add(Change(
                PathPlannerPath.clonePointTowardsZones(zones),
                () {
                  zones.add(PointTowardsZone());
                  widget.onPathChanged?.call();
                },
                (oldValue) {
                  _selectedZone = null;
                  widget.onZoneHovered?.call(null);
                  widget.onZoneSelected?.call(null);
                  widget.path.pointTowardsZones =
                      PathPlannerPath.clonePointTowardsZones(oldValue);
                  widget.onPathChanged?.call();
                },
              ));
            },
            tooltip: 'Add New Point Towards Zone',
          ),
          const SizedBox(width: 8),
          ItemCount(count: zones.length),
        ],
      ),
      initiallyExpanded: widget.path.pointTowardsZonesExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          widget.path.pointTowardsZonesExpanded = value;
          if (value == false) {
            _selectedZone = null;
            widget.onZoneSelected?.call(null);
          }
        }
      },
      elevation: 1.0,
      children: [
        const Center(
          child: Text('Zones at the top of the list have higher priority'),
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < zones.length; i++) _buildZoneCard(i),
      ],
    );
  }

  Widget _buildZoneCard(int zoneIdx) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return TreeCardNode(
      controller: _controllers[zoneIdx],
      onHoverStart: () => widget.onZoneHovered?.call(zoneIdx),
      onHoverEnd: () => widget.onZoneHovered?.call(null),
      onExpansionChanged: (expanded) {
        if (expanded ?? false) {
          if (_selectedZone != null) {
            _controllers[_selectedZone!].collapse();
          }
          _selectedZone = zoneIdx;
          widget.onZoneSelected?.call(zoneIdx);
        } else {
          if (zoneIdx == _selectedZone) {
            _selectedZone = null;
            widget.onZoneSelected?.call(null);
          }
        }
      },
      title: Row(
        children: [
          RenamableTitle(
            title: zones[zoneIdx].name,
            onRename: (value) {
              widget.undoStack.add(Change(
                zones[zoneIdx].name,
                () {
                  zones[zoneIdx].name = value;
                  widget.onPathChangedNoSim?.call();
                },
                (oldValue) {
                  zones[zoneIdx].name = oldValue;
                  widget.onPathChangedNoSim?.call();
                },
              ));
            },
          ),
          Expanded(child: Container()),
          Visibility(
            visible: _selectedZone == null,
            child: Tooltip(
              message: 'Move Zone Up',
              waitDuration: const Duration(seconds: 1),
              child: IconButton(
                icon: const Icon(Icons.expand_less),
                color: colorScheme.onSurface,
                onPressed: zoneIdx == 0
                    ? null
                    : () {
                        var temp = zones[zoneIdx - 1];
                        zones[zoneIdx - 1] = zones[zoneIdx];
                        zones[zoneIdx] = temp;

                        var tempController = _controllers[zoneIdx - 1];
                        _controllers[zoneIdx - 1] = _controllers[zoneIdx];
                        _controllers[zoneIdx] = tempController;

                        widget.onPathChanged?.call();
                      },
              ),
            ),
          ),
          Visibility(
            visible: _selectedZone == null,
            child: Tooltip(
              message: 'Move Zone Down',
              waitDuration: const Duration(seconds: 1),
              child: IconButton(
                icon: const Icon(Icons.expand_more),
                color: colorScheme.onSurface,
                onPressed: zoneIdx == zones.length - 1
                    ? null
                    : () {
                        var temp = zones[zoneIdx + 1];
                        zones[zoneIdx + 1] = zones[zoneIdx];
                        zones[zoneIdx] = temp;

                        var tempController = _controllers[zoneIdx + 1];
                        _controllers[zoneIdx + 1] = _controllers[zoneIdx];
                        _controllers[zoneIdx] = tempController;

                        widget.onPathChanged?.call();
                      },
              ),
            ),
          ),
          Tooltip(
            message: 'Delete Zone',
            waitDuration: const Duration(seconds: 1),
            child: IconButton(
              icon: const Icon(Icons.delete_forever),
              color: colorScheme.error,
              onPressed: () {
                widget.undoStack.add(Change(
                  PathPlannerPath.clonePointTowardsZones(zones),
                  () {
                    zones.removeAt(zoneIdx);
                    widget.onZoneSelected?.call(null);
                    widget.onZoneHovered?.call(null);
                    widget.onPathChanged?.call();
                  },
                  (oldValue) {
                    widget.path.pointTowardsZones =
                        PathPlannerPath.clonePointTowardsZones(oldValue);
                    widget.onZoneSelected?.call(null);
                    widget.onZoneHovered?.call(null);
                    widget.onPathChanged?.call();
                  },
                ));
              },
            ),
          ),
        ],
      ),
      initiallyExpanded: zoneIdx == _selectedZone,
      elevation: 4.0,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialValue: zones[zoneIdx].fieldPosition.x,
                  label: 'Field Position X (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(
                          zoneIdx,
                          () => zones[zoneIdx].fieldPosition = Translation2d(
                              value, zones[zoneIdx].fieldPosition.y));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue: zones[zoneIdx].fieldPosition.y,
                  label: 'Field Position Y (M)',
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(
                          zoneIdx,
                          () => zones[zoneIdx].fieldPosition = Translation2d(
                              zones[zoneIdx].fieldPosition.x, value));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialValue: zones[zoneIdx].rotationOffset.degrees,
                  label: 'Rotation Offset (Deg)',
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(
                          zoneIdx,
                          () => zones[zoneIdx].rotationOffset =
                              Rotation2d.fromDegrees(
                                  MathUtil.inputModulus(value, -180, 180)));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: zones[zoneIdx].minWaypointRelativePos.toDouble(),
                secondaryTrackValue:
                    zones[zoneIdx].maxWaypointRelativePos.toDouble(),
                min: 0.0,
                max: waypoints.length - 1.0,
                label: zones[zoneIdx].minWaypointRelativePos.toStringAsFixed(2),
                onChangeStart: (value) {
                  _sliderChangeStart = value;
                },
                onChangeEnd: (value) {
                  widget.undoStack.add(Change(
                    _sliderChangeStart,
                    () {
                      zones[zoneIdx].minWaypointRelativePos = value;
                      widget.onPathChanged?.call();
                    },
                    (oldValue) {
                      zones[zoneIdx].minWaypointRelativePos = oldValue;
                      widget.onPathChanged?.call();
                    },
                  ));
                },
                onChanged: (value) {
                  if (value <= zones[zoneIdx].maxWaypointRelativePos) {
                    zones[zoneIdx].minWaypointRelativePos = value;
                    widget.onPathChangedNoSim?.call();
                  }
                },
              ),
            ),
            SizedBox(
              width: 75,
              child: NumberTextField(
                initialValue: zones[zoneIdx].minWaypointRelativePos,
                precision: 2,
                label: 'Start Pos',
                onSubmitted: (value) {
                  if (value != null) {
                    final maxVal = zones[zoneIdx].maxWaypointRelativePos;
                    final val = MathUtil.clamp(value, 0.0, maxVal);
                    widget.undoStack.add(Change(
                      zones[zoneIdx].minWaypointRelativePos,
                      () {
                        zones[zoneIdx].minWaypointRelativePos = val;
                        widget.onPathChanged?.call();
                      },
                      (oldValue) {
                        zones[zoneIdx].minWaypointRelativePos = oldValue;
                        widget.onPathChanged?.call();
                      },
                    ));
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: zones[zoneIdx].maxWaypointRelativePos.toDouble(),
                min: 0.0,
                max: waypoints.length - 1.0,
                label: zones[zoneIdx].maxWaypointRelativePos.toStringAsFixed(2),
                onChangeStart: (value) {
                  _sliderChangeStart = value;
                },
                onChangeEnd: (value) {
                  widget.undoStack.add(Change(
                    _sliderChangeStart,
                    () {
                      zones[zoneIdx].maxWaypointRelativePos = value;
                      widget.onPathChanged?.call();
                    },
                    (oldValue) {
                      zones[zoneIdx].maxWaypointRelativePos = oldValue;
                      widget.onPathChanged?.call();
                    },
                  ));
                },
                onChanged: (value) {
                  if (value >= zones[zoneIdx].minWaypointRelativePos) {
                    zones[zoneIdx].maxWaypointRelativePos = value;
                    widget.onPathChangedNoSim?.call();
                  }
                },
              ),
            ),
            SizedBox(
              width: 75,
              child: NumberTextField(
                initialValue: zones[zoneIdx].maxWaypointRelativePos,
                precision: 2,
                label: 'End Pos',
                onSubmitted: (value) {
                  if (value != null) {
                    final minVal = zones[zoneIdx].minWaypointRelativePos;
                    final val =
                        MathUtil.clamp(value, minVal, waypoints.length - 1.0);
                    widget.undoStack.add(Change(
                      zones[zoneIdx].maxWaypointRelativePos,
                      () {
                        zones[zoneIdx].maxWaypointRelativePos = val;
                        widget.onPathChanged?.call();
                      },
                      (oldValue) {
                        zones[zoneIdx].maxWaypointRelativePos = oldValue;
                        widget.onPathChanged?.call();
                      },
                    ));
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ],
    );
  }

  void _addChange(int zoneIdx, VoidCallback execute) {
    widget.undoStack.add(Change(
      zones[zoneIdx].clone(),
      () {
        execute.call();
        widget.onPathChanged?.call();
      },
      (oldValue) {
        zones[zoneIdx] = oldValue.clone();
        widget.onPathChanged?.call();
      },
    ));
  }
}
