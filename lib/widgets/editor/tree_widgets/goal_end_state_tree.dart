import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class GoalEndStateTree extends StatelessWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;

  const GoalEndStateTree({
    super.key,
    required this.path,
    this.onPathChanged,
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
                  initialText: path.goalEndState.velocity.toStringAsFixed(2),
                  label: 'Velocity (M/S)',
                  onSubmitted: (value) {
                    if (value != null && value >= 0) {
                      _addChange(() => path.goalEndState.velocity = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: path.goalEndState.rotation.toStringAsFixed(2),
                  label: 'Rotation (Deg)',
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(() => path.goalEndState.rotation = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addChange(VoidCallback execute) {
    UndoRedo.addChange(Change(
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