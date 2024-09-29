import 'package:flutter/material.dart';
import 'package:pathplanner/path/path_constraints.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/tree_card_node.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class GlobalConstraintsTree extends StatelessWidget {
  final PathPlannerPath path;
  final VoidCallback? onPathChanged;
  final ChangeStack undoStack;
  final PathConstraints defaultConstraints;

  const GlobalConstraintsTree({
    super.key,
    required this.path,
    this.onPathChanged,
    required this.undoStack,
    required this.defaultConstraints,
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
                      path.globalConstraints.maxVelocityMPS.toStringAsFixed(2),
                  label: 'Max Velocity (M/S)',
                  enabled: !path.useDefaultConstraints,
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(
                          () => path.globalConstraints.maxVelocityMPS = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: path.globalConstraints.maxAccelerationMPSSq
                      .toStringAsFixed(2),
                  label: 'Max Acceleration (M/S²)',
                  enabled: !path.useDefaultConstraints,
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(() =>
                          path.globalConstraints.maxAccelerationMPSSq = value);
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
                  initialText: path.globalConstraints.maxAngularVelocityDeg
                      .toStringAsFixed(2),
                  label: 'Max Angular Velocity (Deg/S)',
                  arrowKeyIncrement: 1.0,
                  enabled: !path.useDefaultConstraints,
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(() =>
                          path.globalConstraints.maxAngularVelocityDeg = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NumberTextField(
                  initialText: path.globalConstraints.maxAngularAccelerationDeg
                      .toStringAsFixed(2),
                  label: 'Max Angular Acceleration (Deg/S²)',
                  arrowKeyIncrement: 1.0,
                  enabled: !path.useDefaultConstraints,
                  onSubmitted: (value) {
                    if (value != null && value > 0) {
                      _addChange(() => path
                          .globalConstraints.maxAngularAccelerationDeg = value);
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
              Checkbox(
                value: path.useDefaultConstraints,
                onChanged: (value) {
                  undoStack.add(Change(
                    (
                      path.useDefaultConstraints,
                      path.globalConstraints.clone()
                    ),
                    () {
                      path.useDefaultConstraints = value ?? false;
                      path.globalConstraints = defaultConstraints.clone();
                      onPathChanged?.call();
                    },
                    (oldValue) {
                      path.useDefaultConstraints = oldValue.$1;
                      path.globalConstraints = oldValue.$2.clone();
                      onPathChanged?.call();
                    },
                  ));
                },
              ),
              const SizedBox(width: 4),
              const Text(
                'Use Default Constraints',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addChange(VoidCallback execute) {
    undoStack.add(Change(
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
