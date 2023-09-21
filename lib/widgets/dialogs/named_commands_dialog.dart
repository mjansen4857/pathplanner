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
                        onPressed: () => _showRenameDialog(commandName),
                        icon: const Icon(Icons.edit),
                      ),
                    ),
                    Tooltip(
                      message: 'Remove named command',
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                    title: const Text('Remove Named Command'),
                                    content: Text(
                                        'Are you sure you want to remove the named command "$commandName"? This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: Navigator.of(context).pop,
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            widget
                                                .onCommandDeleted(commandName);
                                            Command.named.remove(commandName);
                                          });

                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ));
                        },
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

  void _showRenameDialog(String originalName) {
    TextEditingController controller =
        TextEditingController(text: originalName);

    ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename Command'),
        content: SizedBox(
          height: 42,
          width: 400,
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              labelText: 'Command Name',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text == originalName) {
                Navigator.of(context).pop();
              } else if (Command.named.contains(controller.text)) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('A command with that name already exists'),
                  ),
                );
              } else {
                Navigator.of(context).pop();
                setState(() {
                  widget.onCommandRenamed(originalName, controller.text);
                  Command.named.remove(originalName);
                  Command.named.add(controller.text);
                });
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
