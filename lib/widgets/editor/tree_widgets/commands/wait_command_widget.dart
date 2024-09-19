import 'package:flutter/material.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/widgets/editor/tree_widgets/commands/duplicate_command_button.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class WaitCommandWidget extends StatelessWidget {
  final WaitCommand command;
  final VoidCallback? onUpdated;
  final VoidCallback? onRemoved;
  final ChangeStack undoStack;
  final VoidCallback? onDuplicateCommand;

  const WaitCommandWidget({
    super.key,
    required this.command,
    this.onUpdated,
    this.onRemoved,
    required this.undoStack,
    this.onDuplicateCommand,
  });

  void _updateWaitTime(double newValue) {
    if (newValue >= 0) {
      undoStack.add(Change(
        command.waitTime,
        () {
          command.waitTime = newValue;
          onUpdated?.call();
        },
        (oldValue) {
          command.waitTime = oldValue;
          onUpdated?.call();
        },
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: NumberTextField(
            initialText: command.waitTime.toStringAsFixed(2),
            label: 'Wait Time (S)',
            onSubmitted: (value) {
              double? parsedValue = double.tryParse(value.toString());
              if (parsedValue != null && parsedValue >= 0) {
                _updateWaitTime(parsedValue);
              }
            },
            arrowKeyIncrement: 0.1,
          ),
        ),
        const SizedBox(width: 12),
        DuplicateCommandButton(
          onPressed: onDuplicateCommand,
        ),
        Tooltip(
          message: 'Remove Command',
          waitDuration: const Duration(milliseconds: 500),
          child: IconButton(
            onPressed: onRemoved,
            visualDensity: const VisualDensity(
                horizontal: VisualDensity.minimumDensity,
                vertical: VisualDensity.minimumDensity),
            icon: Icon(Icons.delete, color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}
