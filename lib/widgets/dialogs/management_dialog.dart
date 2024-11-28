import 'package:flutter/material.dart';
import 'package:pathplanner/pages/project/project_page.dart';
import 'package:pathplanner/path/waypoint.dart';

class ManagementDialog extends StatefulWidget {
  final Function(String, String) onEventRenamed;
  final Function(String) onEventDeleted;
  final Function(String, String) onLinkedRenamed;
  final Function(String) onLinkedDeleted;

  const ManagementDialog({
    super.key,
    required this.onEventRenamed,
    required this.onEventDeleted,
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
                                child: Text('Manage Events'),
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
                      _buildEventsTab(),
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

  Widget _buildEventsTab() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (ProjectPage.events.isEmpty) {
      return const Center(child: Text('No Events in Project'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (String eventName in ProjectPage.events)
            if (eventName.isNotEmpty)
              ListTile(
                title: Text(eventName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Rename event',
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        onPressed: () => _showRenameEventDialog(eventName),
                        icon: const Icon(Icons.edit),
                      ),
                    ),
                    Tooltip(
                      message: 'Remove event',
                      waitDuration: const Duration(milliseconds: 500),
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                    title: const Text('Remove Event'),
                                    content: Text(
                                        'Are you sure you want to remove the event "$eventName"? This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: Navigator.of(context).pop,
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            widget.onEventDeleted(eventName);
                                            ProjectPage.events
                                                .remove(eventName);
                                          });

                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ));
                        },
                        icon: Icon(
                          Icons.delete_forever_rounded,
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
                        Icons.delete_forever_rounded,
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

  void _showRenameEventDialog(String originalName) {
    TextEditingController controller =
        TextEditingController(text: originalName);

    ColorScheme colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename Event'),
        content: SizedBox(
          height: 42,
          width: 400,
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              labelText: 'Event Name',
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
              } else if (ProjectPage.events.contains(controller.text)) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('An event with that name already exists'),
                  ),
                );
              } else {
                Navigator.of(context).pop();
                setState(() {
                  widget.onEventRenamed(originalName, controller.text);
                  ProjectPage.events.remove(originalName);
                  ProjectPage.events.add(controller.text);
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
