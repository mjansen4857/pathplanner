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

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: NumberTextField(
            value: command.waitTime,
            label: 'Wait Time (S)',
            onSubmitted: (value) {
              if (value >= 0) {
                undoStack.add(Change(
                  command.waitTime,
                  () {
                    command.waitTime = value;
                    onUpdated?.call();
                  },
                  (oldValue) {
                    command.waitTime = oldValue;
                    onUpdated?.call();
                  },
                ));
              }
            },
          ),
        ),
        DuplicateCommandButton(
          onPressed: onDuplicateCommand,
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Remove Command',
          waitDuration: const Duration(milliseconds: 500),
          child: IconButton(
            onPressed: onRemoved,
            visualDensity: const VisualDensity(
                horizontal: VisualDensity.minimumDensity,
                vertical: VisualDensity.minimumDensity),
            icon: Icon(Icons.close, color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}
