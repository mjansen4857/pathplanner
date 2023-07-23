import 'package:flutter/material.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/services/undo_redo.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class GlobalConstraintsTree extends StatelessWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;

  const GlobalConstraintsTree({
    super.key,
    required this.path,
    this.onPathChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TreeCardNode(
      title: const Text('Global Constraints'),
      initiallyExpanded: path.globalConstraintsExpanded,
      onExpansionChanged: (value) {
        if (value != null) {
          path.globalConstraintsExpanded = value;
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
                      path.globalConstraints.maxVelocity.toStringAsFixed(2),
                  label: 'Max Velocity (M/S)',
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(
                          () => path.globalConstraints.maxVelocity = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText:
                      path.globalConstraints.maxAcceleration.toStringAsFixed(2),
                  label: 'Max Acceleration (M/S²)',
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(
                          () => path.globalConstraints.maxAcceleration = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              Expanded(
                child: NumberTextField(
                  initialText: path.globalConstraints.maxAngularVelocity
                      .toStringAsFixed(2),
                  label: 'Max Angular Velocity (Deg/S)',
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(() =>
                          path.globalConstraints.maxAngularVelocity = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: path.globalConstraints.maxAngularAcceleration
                      .toStringAsFixed(2),
                  label: 'Max Angular Acceleration (Deg/S²)',
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(() => path
                          .globalConstraints.maxAngularAcceleration = value);
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
      path.globalConstraints.clone(),
      () {
        execute.call();
        onPathChanged?.call();
      },
      (oldValue) {
        path.globalConstraints = oldValue.clone();
        onPathChanged?.call();
      },
    ));
  }
}