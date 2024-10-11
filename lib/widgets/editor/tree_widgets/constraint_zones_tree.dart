import 'package:flutter/material.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:undo/undo.dart';

class ConstraintZonesTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final VoidCallback? onPathChangedNoSim;
  final ValueChanged<int?>? onZoneHovered;
  final ValueChanged<int?>? onZoneSelected;
  final int? initiallySelectedZone;
  final ChangeStack undoStack;

  const ConstraintZonesTree({
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
  State<ConstraintZonesTree> createState() => _ConstraintZonesTreeState();
}

class _ConstraintZonesTreeState extends State<ConstraintZonesTree> {
  List<ConstraintsZone> get constraintZones => widget.path.constraintZones;
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedZone;

  double _sliderChangeStart = 0;

  @override
  void initState() {
    super.initState();

    _selectedZone = widget.initiallySelectedZone;

    _controllers = List.generate(
        constraintZones.length, (index) => ExpansionTileController());
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Constraint Zones'),
      leading: const Icon(Icons.speed_rounded),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              widget.undoStack.add(Change(
                PathPlannerPath.cloneConstraintZones(constraintZones),
                () {
                  final constraints = widget.path.globalConstraints.clone();
                  constraints.unlimited = false;
                  constraintZones.add(ConstraintsZone.defaultZone(
                    constraints: constraints,
                  ));
                  widget.onPathChangedNoSim?.call();
                },
                (oldValue) {
                  _selectedZone = null;
                  widget.onZoneHovered?.call(null);
                  widget.onZoneSelected?.call(null);
                  widget.path.constraintZones =
                      PathPlannerPath.cloneConstraintZones(oldValue);
                  widget.onPathChangedNoSim?.call();
                },
              ));
            },
            tooltip: 'Add New Constraint Zone',
          ),
          const SizedBox(width: 8),
          ItemCount(count: widget.path.constraintZones.length),
        ],
      ),
      initiallyExpanded: widget.path.constraintZonesExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          widget.path.constraintZonesExpanded = value;
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
        for (int i = 0; i < constraintZones.length; i++) _buildZoneCard(i),
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
            title: constraintZones[zoneIdx].name,
            onRename: (value) {
              widget.undoStack.add(Change(
                constraintZones[zoneIdx].name,
                () {
                  constraintZones[zoneIdx].name = value;
                  widget.onPathChangedNoSim?.call();
                },
                (oldValue) {
                  constraintZones[zoneIdx].name = oldValue;
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
                        var temp = constraintZones[zoneIdx - 1];
                        constraintZones[zoneIdx - 1] = constraintZones[zoneIdx];
                        constraintZones[zoneIdx] = temp;

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
                onPressed: zoneIdx == constraintZones.length - 1
                    ? null
                    : () {
                        var temp = constraintZones[zoneIdx + 1];
                        constraintZones[zoneIdx + 1] = constraintZones[zoneIdx];
                        constraintZones[zoneIdx] = temp;

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
                  PathPlannerPath.cloneConstraintZones(
                      widget.path.constraintZones),
                  () {
                    constraintZones.removeAt(zoneIdx);
                    widget.onZoneSelected?.call(null);
                    widget.onZoneHovered?.call(null);
                    widget.onPathChanged?.call();
                  },
                  (oldValue) {
                    widget.path.constraintZones =
                        PathPlannerPath.cloneConstraintZones(oldValue);
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
                  initialValue:
                      constraintZones[zoneIdx].constraints.maxVelocityMPS,
                  label: 'Max Velocity (M/S)',
                  minValue: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addConstraintsChange(
                          zoneIdx,
                          () => constraintZones[zoneIdx]
                              .constraints
                              .maxVelocityMPS = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue:
                      constraintZones[zoneIdx].constraints.maxAccelerationMPSSq,
                  label: 'Max Acceleration (M/S²)',
                  minValue: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addConstraintsChange(
                          zoneIdx,
                          () => constraintZones[zoneIdx]
                              .constraints
                              .maxAccelerationMPSSq = value);
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
                  initialValue: constraintZones[zoneIdx]
                      .constraints
                      .maxAngularVelocityDeg,
                  label: 'Max Angular Velocity (Deg/S)',
                  arrowKeyIncrement: 1.0,
                  minValue: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addConstraintsChange(
                          zoneIdx,
                          () => constraintZones[zoneIdx]
                              .constraints
                              .maxAngularVelocityDeg = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialValue: constraintZones[zoneIdx]
                      .constraints
                      .maxAngularAccelerationDeg,
                  label: 'Max Angular Acceleration (Deg/S²)',
                  arrowKeyIncrement: 1.0,
                  minValue: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addConstraintsChange(
                          zoneIdx,
                          () => constraintZones[zoneIdx]
                              .constraints
                              .maxAngularAccelerationDeg = value);
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
                  initialValue:
                      constraintZones[zoneIdx].constraints.nominalVoltage,
                  label: 'Nominal Voltage (Volts)',
                  minValue: 6.0,
                  maxValue: 13.0,
                  arrowKeyIncrement: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addConstraintsChange(
                          zoneIdx,
                          () => constraintZones[zoneIdx]
                              .constraints
                              .nominalVoltage = value);
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
                value:
                    constraintZones[zoneIdx].minWaypointRelativePos.toDouble(),
                secondaryTrackValue:
                    constraintZones[zoneIdx].maxWaypointRelativePos.toDouble(),
                min: 0.0,
                max: waypoints.length - 1.0,
                label: constraintZones[zoneIdx]
                    .minWaypointRelativePos
                    .toStringAsFixed(2),
                onChangeStart: (value) {
                  _sliderChangeStart = value;
                },
                onChangeEnd: (value) {
                  widget.undoStack.add(Change(
                    _sliderChangeStart,
                    () {
                      constraintZones[zoneIdx].minWaypointRelativePos = value;
                      widget.onPathChanged?.call();
                    },
                    (oldValue) {
                      constraintZones[zoneIdx].minWaypointRelativePos =
                          oldValue;
                      widget.onPathChanged?.call();
                    },
                  ));
                },
                onChanged: (value) {
                  if (value <=
                      constraintZones[zoneIdx].maxWaypointRelativePos) {
                    constraintZones[zoneIdx].minWaypointRelativePos = value;
                    widget.onPathChangedNoSim?.call();
                  }
                },
              ),
            ),
            SizedBox(
              width: 75,
              child: NumberTextField(
                initialValue: constraintZones[zoneIdx].minWaypointRelativePos,
                precision: 2,
                label: 'Start Pos',
                onSubmitted: (value) {
                  if (value != null) {
                    final maxVal =
                        constraintZones[zoneIdx].maxWaypointRelativePos;
                    final val = MathUtil.clamp(value, 0.0, maxVal);
                    widget.undoStack.add(Change(
                      constraintZones[zoneIdx].minWaypointRelativePos,
                      () {
                        constraintZones[zoneIdx].minWaypointRelativePos = val;
                        widget.onPathChanged?.call();
                      },
                      (oldValue) {
                        constraintZones[zoneIdx].minWaypointRelativePos =
                            oldValue;
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
                value:
                    constraintZones[zoneIdx].maxWaypointRelativePos.toDouble(),
                min: 0.0,
                max: waypoints.length - 1.0,
                label: constraintZones[zoneIdx]
                    .maxWaypointRelativePos
                    .toStringAsFixed(2),
                onChangeStart: (value) {
                  _sliderChangeStart = value;
                },
                onChangeEnd: (value) {
                  widget.undoStack.add(Change(
                    _sliderChangeStart,
                    () {
                      constraintZones[zoneIdx].maxWaypointRelativePos = value;
                      widget.onPathChanged?.call();
                    },
                    (oldValue) {
                      constraintZones[zoneIdx].maxWaypointRelativePos =
                          oldValue;
                      widget.onPathChanged?.call();
                    },
                  ));
                },
                onChanged: (value) {
                  if (value >=
                      constraintZones[zoneIdx].minWaypointRelativePos) {
                    constraintZones[zoneIdx].maxWaypointRelativePos = value;
                    widget.onPathChangedNoSim?.call();
                  }
                },
              ),
            ),
            SizedBox(
              width: 75,
              child: NumberTextField(
                initialValue: constraintZones[zoneIdx].maxWaypointRelativePos,
                precision: 2,
                label: 'End Pos',
                onSubmitted: (value) {
                  if (value != null) {
                    final minVal =
                        constraintZones[zoneIdx].minWaypointRelativePos;
                    final val =
                        MathUtil.clamp(value, minVal, waypoints.length - 1);
                    widget.undoStack.add(Change(
                      constraintZones[zoneIdx].maxWaypointRelativePos,
                      () {
                        constraintZones[zoneIdx].maxWaypointRelativePos = val;
                        widget.onPathChanged?.call();
                      },
                      (oldValue) {
                        constraintZones[zoneIdx].maxWaypointRelativePos =
                            oldValue;
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

  void _addConstraintsChange(int zoneIdx, VoidCallback execute) {
    widget.undoStack.add(Change(
      constraintZones[zoneIdx].constraints.clone(),
      () {
        execute.call();
        widget.onPathChanged?.call();
      },
      (oldValue) {
        constraintZones[zoneIdx].constraints = oldValue.clone();
        widget.onPathChanged?.call();
      },
    ));
  }
}
