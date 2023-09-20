import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';

class NamedCommandsDialog extends StatefulWidget {
  final Function(String, String) onCommandRenamed;
  final Function(String) onCommandDeleted;

  const NamedCommandsDialog({
    super.key,
    required this.onCommandRenamed,
    required this.onCommandDeleted,
  });

  @override
  State<NamedCommandsDialog> createState() => _NamedCommandsDialogState();
}

class _NamedCommandsDialogState extends State<NamedCommandsDialog> {
  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Manage Named Commands'),
      content: Container(
        width: 500,
        height: 350,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.surfaceVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (String commandName in Command.named)
              ListTile(
                title: Text(commandName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Rename named command',
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit),
                      ),
                    ),
                    Tooltip(
                      message: 'Remove named command',
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Close'),
        ),
      ],
    );
  }
}
