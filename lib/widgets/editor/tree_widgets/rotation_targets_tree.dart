import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/units.dart';
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
      trailing: ItemCount(count: widget.path.rotationTargets.length),
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
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            style: ElevatedButton.styleFrom(
              elevation: 4.0,
            ),
            label: const Text('Add New Rotation Target'),
            onPressed: () {
              widget.undoStack.add(Change(
                PathPlannerPath.cloneRotationTargets(rotations),
                () {
                  rotations.add(RotationTarget());
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
          ),
        ),
      ],
    );
  }

  Widget _buildRotationCard(int targetIdx) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return TreeCardNode(
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
          Text(
              'Rotation Target at ${rotations[targetIdx].waypointRelativePos.toStringAsFixed(2)}'),
          Expanded(child: Container()),
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
                    value: rotations[targetIdx].rotationDegrees,
                    label: 'Rotation (Deg)',
                    arrowKeyIncrement: 1.0,
                    onSubmitted: (value) {
                      widget.undoStack.add(Change(
                        rotations[targetIdx].clone(),
                        () {
                          rotations[targetIdx].rotationDegrees =
                              adjustAngle(value);
                          widget.onPathChanged?.call();
                        },
                        (oldValue) {
                          rotations[targetIdx].rotationDegrees =
                              oldValue.rotationDegrees;
                          widget.onPathChanged?.call();
                        },
                      ));
                    }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: rotations[targetIdx].rotateFast,
              onChanged: (value) {
                widget.undoStack.add(Change(
                  rotations[targetIdx].clone(),
                  () {
                    rotations[targetIdx].rotateFast = value ?? false;
                    widget.onPathChanged?.call();
                  },
                  (oldValue) {
                    rotations[targetIdx].rotateFast = oldValue.rotateFast;
                    widget.onPathChanged?.call();
                  },
                ));
              },
            ),
            const SizedBox(width: 4),
            const Text(
              'Reach as Fast as Possible',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: rotations[targetIdx].waypointRelativePos.toDouble(),
          min: 0.0,
          max: waypoints.length - 1.0,
          divisions: (waypoints.length - 1) * 20,
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
            rotations[targetIdx].waypointRelativePos = value;
            widget.onPathChangedNoSim?.call();
          },
        ),
      ],
    );
  }
}
