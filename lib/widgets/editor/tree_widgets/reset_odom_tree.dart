import 'package:flutter/material.dart';
import 'package:pathplanner/auto/pathplanner_auto.dart';
import 'package:undo/undo.dart';

class ResetOdomTree extends StatelessWidget {
  final PathPlannerAuto auto;
  final VoidCallback? onAutoChanged;
  final ChangeStack undoStack;

  const ResetOdomTree({
    super.key,
    required this.auto,
    this.onAutoChanged,
    required this.undoStack,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1.0,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Tooltip(
          message: 'Reset the robot\'s odometry at the start of this auto?',
          child: Row(
            children: [
              Checkbox(
                value: auto.resetOdom,
                onChanged: (val) {
                  if (val != null) {
                    undoStack.add(Change(
                      auto.resetOdom,
                      () {
                        auto.resetOdom = val;
                        onAutoChanged?.call();
                      },
                      (oldValue) {
                        auto.resetOdom = oldValue;
                        onAutoChanged?.call();
                      },
                    ));
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.only(
                  bottom: 3.0,
                  left: 4.0,
                ),
                child: Text(
                  'Reset Odometry',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
