import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';
import 'package:pathplanner/util/wpimath/math_util.dart';
import 'package:pathplanner/widgets/editor/info_card.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class IdealStartingStateTree extends StatelessWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ChangeStack undoStack;
  final bool holonomicMode;

  const IdealStartingStateTree({
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
          const Text('Preview Starting State'),
          InfoCard(
              value:
                  '${path.idealStartingState.rotation.degrees.toStringAsFixed(2)}° starting with ${path.idealStartingState.velocityMPS.toStringAsFixed(2)} M/S'),
        ],
      ),
      leading: const Icon(Icons.start_rounded),
      initiallyExpanded: path.previewStartingStateExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          path.previewStartingStateExpanded = value;
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
                  initialValue: path.idealStartingState.velocityMPS,
                  label: 'Velocity (M/S)',
                  arrowKeyIncrement: 0.1,
                  minValue: 0.0,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(() => path.idealStartingState.velocityMPS = value);
                    }
                  },
                ),
              ),
              if (holonomicMode) const SizedBox(width: 8),
              if (holonomicMode)
                Expanded(
                  child: NumberTextField(
                    initialValue: path.idealStartingState.rotation.degrees,
                    label: 'Rotation (Deg)',
                    onSubmitted: (value) {
                      if (value != null) {
                        _addChange(() => path.idealStartingState.rotation =
                            Rotation2d.fromDegrees(MathUtil.inputModulus(value, -180, 180)));
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
      path.idealStartingState.clone(),
      () {
        execute.call();
        onPathChanged?.call();
      },
      (oldValue) {
        path.idealStartingState = oldValue.clone();
        onPathChanged?.call();
      },
    ));
  }
}
