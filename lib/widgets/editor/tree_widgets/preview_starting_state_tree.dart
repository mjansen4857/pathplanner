import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/preview_starting_state.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class PreviewStartingStateTree extends StatelessWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ChangeStack undoStack;
  final bool holonomicMode;

  const PreviewStartingStateTree({
    super.key,
    required this.path,
    this.onPathChanged,
    required this.undoStack,
    required this.holonomicMode,
  });

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Preview Starting State'),
      icon: const Icon(Icons.play_circle_outline),
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
                      path.previewStartingState?.velocity.toStringAsFixed(2) ??
                          '',
                  label: 'Velocity (M/S)',
                  arrowKeyIncrement: 0.1,
                  enabled: path.previewStartingState != null,
                  onSubmitted: (value) {
                    if (value != null) {
                      _addChange(
                          () => path.previewStartingState!.velocity = value);
                    }
                  },
                ),
              ),
              if (holonomicMode) const SizedBox(width: 8),
              if (holonomicMode)
                Expanded(
                  child: NumberTextField(
                    initialText: path.previewStartingState?.rotation
                            .toStringAsFixed(2) ??
                        '',
                    label: 'Rotation (Deg)',
                    enabled: path.previewStartingState != null,
                    onSubmitted: (value) {
                      if (value != null) {
                        num rot = value % 360;
                        if (rot > 180) {
                          rot -= 360;
                        }
                        _addChange(
                            () => path.previewStartingState!.rotation = rot);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: path.previewStartingState != null,
              onChanged: (value) {
                if (value ?? false) {
                  _addChange(() {
                    path.previewStartingState = PreviewStartingState();
                  });
                } else {
                  _addChange(() {
                    path.previewStartingState = null;
                  });
                }
              },
            ),
            const SizedBox(width: 4),
            const Text(
              'Preset Starting State (Preview Only)',
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }

  void _addChange(VoidCallback execute) {
    undoStack.add(Change(
      path.previewStartingState?.clone(),
      () {
        execute.call();
        onPathChanged?.call();
      },
      (oldValue) {
        path.previewStartingState = oldValue?.clone();
        onPathChanged?.call();
      },
    ));
  }
}
