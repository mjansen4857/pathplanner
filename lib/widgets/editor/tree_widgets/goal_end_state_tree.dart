import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class GoalEndStateTree extends StatelessWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ChangeStack undoStack;
  final bool holonomicMode;

  const GoalEndStateTree({
    super.key,
    required this.path,
    this.onPathChanged,
    required this.undoStack,
    required this.holonomicMode,
  });

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Goal End State'),
      initiallyExpanded: path.goalEndStateExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          path.goalEndStateExpanded = value;
        }
      },
      elevation: 1.0,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  value: path.goalEndState.velocity,
                  label: 'Velocity (M/S)',
                  arrowKeyIncrement: 0.1,
                  onSubmitted: (value) {
                    if (value >= 0) {
                      _addChange(() => path.goalEndState.velocity = value);
                    }
                  },
                ),
              ),
              if (holonomicMode) const SizedBox(width: 8),
              if (holonomicMode)
                Expanded(
                  child: NumberTextField(
                    value: path.goalEndState.rotation,
                    label: 'Rotation (Deg)',
                    onSubmitted: (value) {
                      num rot = value % 360;
                      if (rot > 180) {
                        rot -= 360;
                      }
                      _addChange(() => path.goalEndState.rotation = rot);
                    },
                  ),
                ),
            ],
          ),
        ),
        if (holonomicMode) const SizedBox(height: 12),
        if (holonomicMode)
          Row(
            children: [
              Checkbox(
                value: path.goalEndState.rotateFast,
                onChanged: (value) {
                  _addChange(
                      () => path.goalEndState.rotateFast = value ?? false);
                },
              ),
              const SizedBox(width: 4),
              const Text(
                'Rotate as Fast as Possible',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
      ],
    );
  }

  void _addChange(VoidCallback execute) {
    undoStack.add(Change(
      path.goalEndState.clone(),
      () {
        execute.call();
        onPathChanged?.call();
      },
      (oldValue) {
        path.goalEndState = oldValue.clone();
        onPathChanged?.call();
      },
    ));
  }
}
