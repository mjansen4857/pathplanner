import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';
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
      title: Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          const Text('Goal End State'),
          InfoCard(
              value:
                  '${path.goalEndState.rotation.degrees.toStringAsFixed(2)}° ending with ${path.goalEndState.velocityMPS.toStringAsFixed(2)} M/S'),
        ],
      ),
      leading: const Icon(Icons.flag_circle_rounded),
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
                  initialValue: path.goalEndState.velocityMPS,
                  label: 'Velocity (M/S)',
                  arrowKeyIncrement: 0.1,
                  minValue: 0.0,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(() => path.goalEndState.velocityMPS = value);
                    }
                  },
                ),
              )),
              if (holonomicMode) const SizedBox(width: 8),
              if (holonomicMode)
                Expanded(
                  child: NumberTextField(
                    initialValue: path.goalEndState.rotation.degrees,
                    label: 'Rotation (Deg)',
                    onSubmitted: (value) {
                      if (value != null) {
                        _addChange(() => path.goalEndState.rotation =
                            Rotation2d.fromDegrees(
                                MathUtil.inputModulus(value, -180, 180)));
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
