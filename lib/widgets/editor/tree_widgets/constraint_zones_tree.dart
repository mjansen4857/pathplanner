import 'package:flutter/material.dart';
import 'package:pathplanner/path/constraints_zone.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:pathplanner/widgets/renamable_title.dart';
import 'package:undo/undo.dart';

class ConstraintZonesTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ValueChanged<int?>? onZoneHovered;
  final ValueChanged<int?>? onZoneSelected;
  final int? initiallySelectedZone;

  const ConstraintZonesTree({
    super.key,
    required this.path,
    this.onPathChanged,
    this.onZoneHovered,
    this.onZoneSelected,
    this.initiallySelectedZone,
  });

  @override
  State<ConstraintZonesTree> createState() => _ConstraintZonesTreeState();
}

class _ConstraintZonesTreeState extends State<ConstraintZonesTree> {
  List<ConstraintsZone> get constraintZones => widget.path.constraintZones;
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedZone;

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
      initiallyExpanded: widget.path.constraintZonesExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          widget.path.constraintZonesExpanded = value;
          widget.onPathChanged?.call();
        }
      },
      elevation: 1.0,
      children: [
        const Center(
          child: Text('Zones at the top of the list have higher priority'),
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < constraintZones.length; i++) _buildZoneCard(i),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            style: ElevatedButton.styleFrom(
              elevation: 4.0,
            ),
            label: const Text('Add New Zone'),
            onPressed: () {
              constraintZones.add(ConstraintsZone.defaultZone());
              widget.onPathChanged?.call();
            },
          ),
        ),
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
              constraintZones[zoneIdx].name = value;
              widget.onPathChanged?.call();
            },
          ),
          Expanded(child: Container()),
          Visibility(
            visible: _selectedZone == null,
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

                      if (_selectedZone == zoneIdx) {
                        _selectedZone = zoneIdx - 1;
                        widget.onZoneSelected?.call(_selectedZone);
                      } else if (_selectedZone == zoneIdx - 1) {
                        _selectedZone = zoneIdx;
                        widget.onZoneSelected?.call(_selectedZone);
                      }

                      widget.onPathChanged?.call();
                    },
            ),
          ),
          Visibility(
            visible: _selectedZone == null,
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

                      if (_selectedZone == zoneIdx) {
                        _selectedZone = zoneIdx + 1;
                        widget.onZoneSelected?.call(_selectedZone);
                      } else if (_selectedZone == zoneIdx + 1) {
                        _selectedZone = zoneIdx;
                        widget.onZoneSelected?.call(_selectedZone);
                      }

                      widget.onPathChanged?.call();
                    },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            color: colorScheme.error,
            onPressed: () {
              UndoRedo.addChange(Change(
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
                  initialText: constraintZones[zoneIdx]
                      .constraints
                      .maxVelocity
                      .toStringAsFixed(2),
                  label: 'Max Velocity (M/S)',
                  onSubmitted: (value) {
                    if (value != null) {
                      constraintZones[zoneIdx].constraints.maxVelocity = value;
                      widget.onPathChanged?.call();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: constraintZones[zoneIdx]
                      .constraints
                      .maxAcceleration
                      .toStringAsFixed(2),
                  label: 'Max Acceleration (M/S²)',
                  onSubmitted: (value) {
                    if (value != null) {
                      constraintZones[zoneIdx].constraints.maxAcceleration =
                          value;
                      widget.onPathChanged?.call();
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
                  initialText: constraintZones[zoneIdx]
                      .constraints
                      .maxAngularVelocity
                      .toStringAsFixed(2),
                  label: 'Max Angular Velocity (Deg/S)',
                  onSubmitted: (value) {
                    if (value != null) {
                      constraintZones[zoneIdx].constraints.maxAngularVelocity =
                          value;
                      widget.onPathChanged?.call();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: constraintZones[zoneIdx]
                      .constraints
                      .maxAngularAcceleration
                      .toStringAsFixed(2),
                  label: 'Max Angular Acceleration (Deg/S²)',
                  onSubmitted: (value) {
                    if (value != null) {
                      constraintZones[zoneIdx]
                          .constraints
                          .maxAngularAcceleration = value;
                      widget.onPathChanged?.call();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          value: constraintZones[zoneIdx].minWaypointRelativePos.toDouble(),
          secondaryTrackValue:
              constraintZones[zoneIdx].maxWaypointRelativePos.toDouble(),
          min: 0.0,
          max: waypoints.length - 1.0,
          divisions: (waypoints.length - 1) * 20,
          label: constraintZones[zoneIdx]
              .minWaypointRelativePos
              .toStringAsFixed(2),
          onChanged: (value) {
            if (value <= constraintZones[zoneIdx].maxWaypointRelativePos) {
              constraintZones[zoneIdx].minWaypointRelativePos = value;
              widget.onPathChanged?.call();
            }
          },
        ),
        Slider(
          value: constraintZones[zoneIdx].maxWaypointRelativePos.toDouble(),
          min: 0.0,
          max: waypoints.length - 1.0,
          divisions: (waypoints.length - 1) * 20,
          label: constraintZones[zoneIdx]
              .maxWaypointRelativePos
              .toStringAsFixed(2),
          onChanged: (value) {
            if (value >= constraintZones[zoneIdx].minWaypointRelativePos) {
              constraintZones[zoneIdx].maxWaypointRelativePos = value;
              widget.onPathChanged?.call();
            }
          },
        ),
      ],
    );
  }
}
