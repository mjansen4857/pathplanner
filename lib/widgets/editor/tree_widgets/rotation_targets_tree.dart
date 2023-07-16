import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/rotation_target.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';

class RotationTargetsTree extends StatefulWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ValueChanged<int?>? onTargetHovered;
  final ValueChanged<int?>? onTargetSelected;
  final int? initiallySelectedTarget;

  const RotationTargetsTree({
    super.key,
    required this.path,
    this.onPathChanged,
    this.onTargetHovered,
    this.onTargetSelected,
    this.initiallySelectedTarget,
  });

  @override
  State<RotationTargetsTree> createState() => _RotationTargetsTreeState();
}

class _RotationTargetsTreeState extends State<RotationTargetsTree> {
  List<RotationTarget> get rotations => widget.path.rotationTargets;
  List<Waypoint> get waypoints => widget.path.waypoints;

  late List<ExpansionTileController> _controllers;
  int? _selectedTarget;

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
      initiallyExpanded: true,
      elevation: 1.0,
      children: [
        for (int i = 0; i < rotations.length; i++) _buildRotationCard(i),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add New Rotation Target'),
            onPressed: () {
              rotations.add(RotationTarget());
              widget.onPathChanged?.call();
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
          IconButton(
            icon: const Icon(Icons.delete_forever),
            color: colorScheme.error,
            onPressed: () {
              rotations.removeAt(targetIdx);
              if (_selectedTarget == targetIdx) {
                widget.onTargetSelected?.call(null);
              }
              widget.onTargetHovered?.call(null);
              widget.onPathChanged?.call();
            },
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
                  initialText:
                      rotations[targetIdx].rotationDegrees.toStringAsFixed(2),
                  label: 'Rotation (Deg)',
                  onSubmitted: (value) {
                    if (value != null) {
                      rotations[targetIdx].rotationDegrees = value;
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
          value: rotations[targetIdx].waypointRelativePos.toDouble(),
          min: 0.0,
          max: waypoints.length - 1.0,
          divisions: (waypoints.length - 1) * 20,
          label: rotations[targetIdx].waypointRelativePos.toStringAsFixed(2),
          onChanged: (value) {
            rotations[targetIdx].waypointRelativePos = value;
            widget.onPathChanged?.call();
          },
        ),
      ],
    );
  }
}
