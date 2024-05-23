import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
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
      title: const Text('Ideal Starting State'),
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
                  initialText:
                      path.idealStartingState.velocity.toStringAsFixed(2),
                  label: 'Velocity (M/S)',
                  arrowKeyIncrement: 0.1,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(
                          () => path.idealStartingState.velocity = value);
                    }
                  },
                ),
              ),
              if (holonomicMode) const SizedBox(width: 8),
              if (holonomicMode)
                Expanded(
                  child: NumberTextField(
                    initialText:
                        path.idealStartingState.rotation.toStringAsFixed(2),
                    label: 'Rotation (Deg)',
                    onSubmitted: (value) {
                      if (value != null) {
                        num rot = value % 360;
                        if (rot > 180) {
                          rot -= 360;
                        }
                        _addChange(
                            () => path.idealStartingState.rotation = rot);
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
