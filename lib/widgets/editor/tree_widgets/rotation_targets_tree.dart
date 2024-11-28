import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';
import 'package:pathplanner/widgets/editor/info_card.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/item_count.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class RotationTargetsTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final VoidCallback? onPathChangedNoSim;
  final ValueChanged<int?>? onTargetHovered;
  final ValueChanged<int?>? onTargetSelected;
  final int? initiallySelectedTarget;
  final ChangeStack undoStack;

  const RotationTargetsTree({
    super.key,
    required this.path,
    this.onPathChanged,
    this.onPathChangedNoSim,
    this.onTargetHovered,
    this.onTargetSelected,
    this.initiallySelectedTarget,
    required this.undoStack,
  });

  @override
  State<RotationTargetsTree> createState() => _RotationTargetsTreeState();
}

class _RotationTargetsTreeState extends State<RotationTargetsTree> {
  List<RotationTarget> get rotations => widget.path.rotationTargets;
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedTarget;

  double _sliderChangeStart = 0;

  @override
  void initState() {
    super.initState();

    _selectedTarget = widget.initiallySelectedTarget;

    _controllers =
        List.generate(rotations.length, (index) => ExpansionTileController());
  }

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Rotation Targets'),
      leading: const Icon(Icons.rotate_90_degrees_cw_rounded),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              widget.undoStack.add(Change(
                PathPlannerPath.cloneRotationTargets(rotations),
                () {
                  rotations.add(RotationTarget(0.5, const Rotation2d()));
                  widget.onPathChanged?.call();
                },
                (oldValue) {
                  _selectedTarget = null;
                  widget.onTargetHovered?.call(null);
                  widget.onTargetSelected?.call(null);
                  widget.path.rotationTargets =
                      PathPlannerPath.cloneRotationTargets(oldValue);
                  widget.onPathChanged?.call();
                },
              ));
            },
            tooltip: 'Add New Rotation Target',
          ),
          const SizedBox(width: 8),
          ItemCount(count: widget.path.rotationTargets.length),
        ],
      ),
      initiallyExpanded: widget.path.rotationTargetsExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          widget.path.rotationTargetsExpanded = value;
          if (value == false) {
            _selectedTarget = null;
            widget.onTargetSelected?.call(null);
          }
        }
      },
      elevation: 1.0,
      children: [
        for (int i = 0; i < rotations.length; i++) _buildRotationCard(i),
      ],
    );
  }

  Widget _buildRotationCard(int targetIdx) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return TreeCardNode(
      leading: const Icon(Icons.rotate_right_rounded),
      controller: _controllers[targetIdx],
      onHoverStart: () => widget.onTargetHovered?.call(targetIdx),
      onHoverEnd: () => widget.onTargetHovered?.call(null),
      onExpansionChanged: (expanded) {
        if (expanded ?? false) {
          if (_selectedTarget != null) {
            _controllers[_selectedTarget!].collapse();
          }
          _selectedTarget = targetIdx;
          widget.onTargetSelected?.call(targetIdx);
        } else {
          if (targetIdx == _selectedTarget) {
            _selectedTarget = null;
            widget.onTargetSelected?.call(null);
          }
        }
      },
      title: Row(
        children: [
          Expanded(
            child: Text('Rotation Target ${targetIdx + 1}'),
          ),
          const SizedBox(width: 8),
          InfoCard(
            value:
                '${rotations[targetIdx].rotation.degrees.toStringAsFixed(2)}° at ${rotations[targetIdx].waypointRelativePos.toStringAsFixed(2)}',
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Delete Target',
            waitDuration: const Duration(seconds: 1),
            child: IconButton(
              icon: const Icon(Icons.delete_forever),
              color: colorScheme.error,
              onPressed: () {
                widget.undoStack.add(Change(
                  PathPlannerPath.cloneRotationTargets(
                      widget.path.rotationTargets),
                  () {
                    rotations.removeAt(targetIdx);
                    widget.onTargetSelected?.call(null);
                    widget.onTargetHovered?.call(null);
                    widget.onPathChanged?.call();
                  },
                  (oldValue) {
                    widget.path.rotationTargets =
                        PathPlannerPath.cloneRotationTargets(oldValue);
                    widget.onTargetSelected?.call(null);
                    widget.onTargetHovered?.call(null);
                    widget.onPathChanged?.call();
                  },
                ));
              },
            ),
          ),
        ],
      ),
      initiallyExpanded: targetIdx == _selectedTarget,
      elevation: 4.0,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialValue: rotations[targetIdx].rotation.degrees,
                  label: 'Rotation (Deg)',
                  arrowKeyIncrement: 45,
                  onSubmitted: (value) {
                    if (value != null) {
                      widget.undoStack.add(Change(
                        rotations[targetIdx].clone(),
                        () {
                          rotations[targetIdx].rotation =
                              Rotation2d.fromDegrees(
                                  MathUtil.inputModulus(value, -180, 180));
                          widget.onPathChanged?.call();
                        },
                        (oldValue) {
                          rotations[targetIdx].rotation = oldValue.rotation;
                          widget.onPathChanged?.call();
                        },
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: NumberTextField(
                  initialValue: rotations[targetIdx].waypointRelativePos,
                  label: 'Position',
                  arrowKeyIncrement: 0.1,
                  minValue: 0.0,
                  maxValue: (waypoints.length - 1.0),
                  precision: 2,
                  onSubmitted: (value) {
                    if (value != null) {
                      setState(() {
                        rotations[targetIdx].waypointRelativePos = value;
                        widget.onPathChangedNoSim?.call();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          value: rotations[targetIdx].waypointRelativePos.toDouble(),
          min: 0.0,
          max: waypoints.length - 1.0,
          label: rotations[targetIdx].waypointRelativePos.toStringAsFixed(2),
          onChangeStart: (value) {
            _sliderChangeStart = value;
          },
          onChangeEnd: (value) {
            widget.undoStack.add(Change(
              _sliderChangeStart,
              () {
                rotations[targetIdx].waypointRelativePos = value;
                widget.onPathChanged?.call();
              },
              (oldValue) {
                rotations[targetIdx].waypointRelativePos = oldValue;
                widget.onPathChanged?.call();
              },
            ));
          },
          onChanged: (value) {
            setState(() {
              rotations[targetIdx].waypointRelativePos = value;
              widget.onPathChangedNoSim?.call();
            });
          },
        ),
      ],
    );
  }
}
