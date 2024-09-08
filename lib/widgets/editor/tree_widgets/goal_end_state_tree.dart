import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/info_card.dart';
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
      title: Row(
        children: [
          const Text('Final State'),
          Expanded(child: Container()),
          InfoCard(
              value:
                  '${path.goalEndState.rotation.toStringAsFixed(2)}° with ${path.goalEndState.velocity.toStringAsFixed(2)} M/S'),
        ],
      ),
      icon: const Icon(Icons.flag_circle_rounded),
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
                  child: Tooltip(
                message:
                    'The allowed velocity of the robot at end of the path.',
                child: NumberTextField(
                  initialText: path.goalEndState.velocity.toStringAsFixed(2),
                  label: 'Velocity (M/S)',
                  arrowKeyIncrement: 0.1,
                  onSubmitted: (value) {
                    if (value != null && value >= 0) {
                      _addChange(() => path.goalEndState.velocity = value);
                    }
                  },
                ),
              )),
              if (holonomicMode) const SizedBox(width: 8),
              if (holonomicMode)
                Expanded(
                  child: NumberTextField(
                    initialText: path.goalEndState.rotation.toStringAsFixed(2),
                    label: 'Rotation (Deg)',
                    onSubmitted: (value) {
                      if (value != null) {
                        num rot = value % 360;
                        if (rot > 180) {
                          rot -= 360;
                        }
                        _addChange(() => path.goalEndState.rotation = rot);
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
