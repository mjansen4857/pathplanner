import 'package:flutter/material.dart';
import 'package:pathplanner/commands/command.dart';
import 'package:pathplanner/path/waypoint.dart';

class ManagementDialog extends StatefulWidget {
  final Function(String, String) onCommandRenamed;
  final Function(String) onCommandDeleted;
  final Function(String, String) onLinkedRenamed;
  final Function(String) onLinkedDeleted;

  const ManagementDialog({
    super.key,
    required this.onCommandRenamed,
    required this.onCommandDeleted,
    required this.onLinkedRenamed,
    required this.onLinkedDeleted,
  });

  @override
  State<ManagementDialog> createState() => _ManagementDialogState();
}

class _ManagementDialogState extends State<ManagementDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    title: const TabBar(
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.abc),
                              SizedBox(width: 8),
                              Padding(
                                padding: EdgeInsets.only(bottom: 4.0),
                                child: Text('Manage Named Commands'),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link),
                              SizedBox(width: 8),
                              Padding(
                                padding: EdgeInsets.only(bottom: 4.0),
                                child: Text('Manage Linked Waypoints'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                  ),
                  body: TabBarView(
                    children: [
                      _buildNameCmdTab(),
                      _buildLinkedTab(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Navigator.of(context).pop,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameCmdTab() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (Command.named.isEmpty) {
      return const Center(child: Text('No Named Commands in Project'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                      onPressed: () => _showRenameCmdDialog(commandName),
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
                                          widget.onCommandDeleted(commandName);
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
    );
  }

  Widget _buildLinkedTab() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (Waypoint.linked.isEmpty) {
      return const Center(child: Text('No Linked Waypoints in Project'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (String waypointName in Waypoint.linked.keys)
            ListTile(
              title: Text(waypointName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Rename linked waypoint',
                    waitDuration: const Duration(milliseconds: 500),
                    child: IconButton(
                      onPressed: () => _showRenameLinkedDialog(waypointName),
                      icon: const Icon(Icons.edit),
                    ),
                  ),
                  Tooltip(
                    message: 'Remove linked waypoint',
                    waitDuration: const Duration(milliseconds: 500),
                    child: IconButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                                  title: const Text('Remove Linked Waypoint'),
                                  content: Text(
                                      'Are you sure you want to remove the linked waypoint "$waypointName"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: Navigator.of(context).pop,
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          widget.onLinkedDeleted(waypointName);
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
    );
  }

  void _showRenameCmdDialog(String originalName) {
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

  void _showRenameLinkedDialog(String originalName) {
    TextEditingController controller =
        TextEditingController(text: originalName);

    ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename Linked Waypoint'),
        content: SizedBox(
          height: 42,
          width: 400,
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              labelText: 'Waypoint Name',
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
              } else if (Waypoint.linked.containsKey(controller.text)) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('A linked waypoint with that name already exists'),
                  ),
                );
              } else {
                Navigator.of(context).pop();
                setState(() {
                  widget.onLinkedRenamed(originalName, controller.text);
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
