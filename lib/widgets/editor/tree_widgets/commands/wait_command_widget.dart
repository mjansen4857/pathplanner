import 'package:flutter/material.dart';
import 'package:pathplanner/commands/wait_command.dart';
import 'package:pathplanner/widgets/number_text_field.dart';
import 'package:undo/undo.dart';

class WaitCommandWidget extends StatelessWidget {
  final WaitCommand command;
  final VoidCallback onUpdated;
  final VoidCallback onRemoved;
  final ChangeStack undoStack;

  const WaitCommandWidget({
    super.key,
    required this.command,
    required this.onUpdated,
    required this.onRemoved,
    required this.undoStack,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: NumberTextField(
            initialText: command.waitTime.toStringAsFixed(2),
            label: 'Wait Time (S)',
            onSubmitted: (value) {
              if (value != null && value >= 0) {
                undoStack.add(Change(
                  command.waitTime,
                  () {
                    command.waitTime = value;
                    onUpdated.call();
                  },
                  (oldValue) {
                    command.waitTime = oldValue;
                    onUpdated.call();
                  },
                ));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onRemoved,
          visualDensity: const VisualDensity(
              horizontal: VisualDensity.minimumDensity,
              vertical: VisualDensity.minimumDensity),
          icon: Icon(Icons.close, color: colorScheme.error),
        ),
      ],
    );
  }
}
